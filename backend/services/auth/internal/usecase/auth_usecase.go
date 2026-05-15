package usecase

import (
	"context"
	"fmt"
	"time"

	"github.com/chanon/ultra-sync/services/auth/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/auth/internal/domain/port"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

type AuthUseCase struct {
	userRepo     port.UserRepository
	sessionStore port.SessionStorer
	tokenSigner  port.TokenSigner
}

func New(
	userRepo port.UserRepository,
	sessionStore port.SessionStorer,
	tokenSigner port.TokenSigner,
) *AuthUseCase {
	return &AuthUseCase{
		userRepo:     userRepo,
		sessionStore: sessionStore,
		tokenSigner:  tokenSigner,
	}
}

type RegisterInput struct {
	Email    string
	Password string
	Role     entity.Role
}

func (uc *AuthUseCase) Register(ctx context.Context, in RegisterInput) (*entity.User, error) {
	existing, _ := uc.userRepo.FindByEmail(ctx, in.Email)
	if existing != nil {
		return nil, fmt.Errorf("email already registered")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	user := &entity.User{
		ID:           uuid.New(),
		Email:        in.Email,
		PasswordHash: string(hash),
		Role:         in.Role,
		Status:       entity.StatusPendingVerify,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := uc.userRepo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	return user, nil
}

type LoginInput struct {
	Email    string
	Password string
}

func (uc *AuthUseCase) Login(ctx context.Context, in LoginInput) (*port.TokenPair, error) {
	user, err := uc.userRepo.FindByEmail(ctx, in.Email)
	if err != nil {
		return nil, fmt.Errorf("invalid credentials")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(in.Password)); err != nil {
		return nil, fmt.Errorf("invalid credentials")
	}

	if user.Status != entity.StatusActive {
		return nil, fmt.Errorf("account not active: status=%s", user.Status)
	}

	now := time.Now()
	user.LastLoginAt = &now
	if err := uc.userRepo.Update(ctx, user); err != nil {
		return nil, fmt.Errorf("update last login: %w", err)
	}

	tokens, err := uc.tokenSigner.Issue(ctx, user)
	if err != nil {
		return nil, fmt.Errorf("issue tokens: %w", err)
	}

	session := &entity.Session{
		ID:           uuid.New(),
		UserID:       user.ID,
		RefreshToken: tokens.RefreshToken,
		ExpiresAt:    time.Now().Add(7 * 24 * time.Hour),
	}
	if err := uc.sessionStore.Save(ctx, session); err != nil {
		return nil, fmt.Errorf("save session: %w", err)
	}

	return tokens, nil
}

func (uc *AuthUseCase) RefreshToken(ctx context.Context, refreshToken string) (*port.TokenPair, error) {
	session, err := uc.sessionStore.FindByRefreshToken(ctx, refreshToken)
	if err != nil {
		return nil, fmt.Errorf("invalid refresh token")
	}

	if session.IsRevoked || time.Now().After(session.ExpiresAt) {
		return nil, fmt.Errorf("refresh token expired or revoked")
	}

	user, err := uc.userRepo.FindByID(ctx, session.UserID)
	if err != nil {
		return nil, fmt.Errorf("find user: %w", err)
	}

	if err := uc.sessionStore.Revoke(ctx, session.ID); err != nil {
		return nil, fmt.Errorf("revoke old session: %w", err)
	}

	tokens, err := uc.tokenSigner.Issue(ctx, user)
	if err != nil {
		return nil, fmt.Errorf("issue tokens: %w", err)
	}

	newSession := &entity.Session{
		ID:           uuid.New(),
		UserID:       user.ID,
		RefreshToken: tokens.RefreshToken,
		ExpiresAt:    time.Now().Add(7 * 24 * time.Hour),
	}
	if err := uc.sessionStore.Save(ctx, newSession); err != nil {
		return nil, fmt.Errorf("save new session: %w", err)
	}

	return tokens, nil
}

func (uc *AuthUseCase) Logout(ctx context.Context, refreshToken string) error {
	session, err := uc.sessionStore.FindByRefreshToken(ctx, refreshToken)
	if err != nil {
		return nil // idempotent — already gone
	}
	return uc.sessionStore.Revoke(ctx, session.ID)
}

func (uc *AuthUseCase) Verify(ctx context.Context, accessToken string) (*entity.User, error) {
	return uc.tokenSigner.Verify(ctx, accessToken)
}
