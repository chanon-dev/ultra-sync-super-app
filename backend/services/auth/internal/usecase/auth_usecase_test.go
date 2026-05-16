package usecase_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/chanon/ultra-sync/services/auth/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/auth/internal/domain/port"
	"github.com/chanon/ultra-sync/services/auth/internal/usecase"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// ── Mocks ─────────────────────────────────────────────────────────────────────

type stubUserRepo struct {
	createFn      func(ctx context.Context, user *entity.User) error
	findByIDFn    func(ctx context.Context, id uuid.UUID) (*entity.User, error)
	findByEmailFn func(ctx context.Context, email string) (*entity.User, error)
	updateFn      func(ctx context.Context, user *entity.User) error
}

func (s *stubUserRepo) Create(ctx context.Context, user *entity.User) error {
	return s.createFn(ctx, user)
}
func (s *stubUserRepo) FindByID(ctx context.Context, id uuid.UUID) (*entity.User, error) {
	return s.findByIDFn(ctx, id)
}
func (s *stubUserRepo) FindByEmail(ctx context.Context, email string) (*entity.User, error) {
	return s.findByEmailFn(ctx, email)
}
func (s *stubUserRepo) Update(ctx context.Context, user *entity.User) error {
	return s.updateFn(ctx, user)
}

type stubSessionStore struct {
	saveFn                func(ctx context.Context, session *entity.Session) error
	findByRefreshTokenFn  func(ctx context.Context, token string) (*entity.Session, error)
	revokeFn              func(ctx context.Context, sessionID uuid.UUID) error
}

func (s *stubSessionStore) Save(ctx context.Context, session *entity.Session) error {
	return s.saveFn(ctx, session)
}
func (s *stubSessionStore) FindByRefreshToken(ctx context.Context, token string) (*entity.Session, error) {
	return s.findByRefreshTokenFn(ctx, token)
}
func (s *stubSessionStore) Revoke(ctx context.Context, sessionID uuid.UUID) error {
	return s.revokeFn(ctx, sessionID)
}

type stubTokenSigner struct {
	issueFn  func(ctx context.Context, user *entity.User) (*port.TokenPair, error)
	verifyFn func(ctx context.Context, accessToken string) (*entity.User, error)
}

func (s *stubTokenSigner) Issue(ctx context.Context, user *entity.User) (*port.TokenPair, error) {
	return s.issueFn(ctx, user)
}
func (s *stubTokenSigner) Verify(ctx context.Context, accessToken string) (*entity.User, error) {
	return s.verifyFn(ctx, accessToken)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

var errMissing = errors.New("not found")

func fakeTokens() *port.TokenPair {
	return &port.TokenPair{AccessToken: "access-tok", RefreshToken: "refresh-tok", ExpiresIn: 900}
}

func noopSave(_ context.Context, _ *entity.Session) error    { return nil }
func noopRevoke(_ context.Context, _ uuid.UUID) error        { return nil }
func noopUpdate(_ context.Context, _ *entity.User) error     { return nil }
func noopUserCreate(_ context.Context, _ *entity.User) error { return nil }

// ── Register ──────────────────────────────────────────────────────────────────

func TestRegister_Success(t *testing.T) {
	uc := usecase.New(
		&stubUserRepo{
			findByEmailFn: func(_ context.Context, _ string) (*entity.User, error) { return nil, errMissing },
			createFn:      noopUserCreate,
		},
		&stubSessionStore{},
		&stubTokenSigner{},
	)

	user, err := uc.Register(context.Background(), usecase.RegisterInput{
		Email: "new@example.com", Password: "secret123", Role: entity.RoleUser,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if user.Email != "new@example.com" {
		t.Errorf("expected email new@example.com, got %s", user.Email)
	}
	if user.Status != entity.StatusActive {
		t.Errorf("expected StatusActive, got %s", user.Status)
	}
	if user.PasswordHash == "" {
		t.Error("expected non-empty PasswordHash")
	}
}

func TestRegister_DuplicateEmail(t *testing.T) {
	existing := &entity.User{ID: uuid.New(), Email: "taken@example.com"}
	uc := usecase.New(
		&stubUserRepo{
			findByEmailFn: func(_ context.Context, _ string) (*entity.User, error) { return existing, nil },
		},
		&stubSessionStore{},
		&stubTokenSigner{},
	)

	_, err := uc.Register(context.Background(), usecase.RegisterInput{
		Email: "taken@example.com", Password: "pass", Role: entity.RoleUser,
	})
	if err == nil {
		t.Fatal("expected error for duplicate email")
	}
}

// ── Login ─────────────────────────────────────────────────────────────────────

// buildActiveUser creates a user with a real bcrypt hash at MinCost for speed.
func buildActiveUser(t *testing.T, password string) *entity.User {
	t.Helper()
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("bcrypt: %v", err)
	}
	return &entity.User{
		ID:           uuid.New(),
		Email:        "user@example.com",
		PasswordHash: string(hash),
		Role:         entity.RoleUser,
		Status:       entity.StatusActive,
	}
}

func TestLogin_Success(t *testing.T) {
	user := buildActiveUser(t, "correct-pass")
	uc := usecase.New(
		&stubUserRepo{
			findByEmailFn: func(_ context.Context, _ string) (*entity.User, error) { return user, nil },
			updateFn:      noopUpdate,
		},
		&stubSessionStore{saveFn: noopSave},
		&stubTokenSigner{
			issueFn: func(_ context.Context, _ *entity.User) (*port.TokenPair, error) { return fakeTokens(), nil },
		},
	)

	tokens, err := uc.Login(context.Background(), usecase.LoginInput{
		Email: "user@example.com", Password: "correct-pass",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tokens.AccessToken != "access-tok" {
		t.Errorf("unexpected access token: %s", tokens.AccessToken)
	}
}

func TestLogin_UserNotFound(t *testing.T) {
	uc := usecase.New(
		&stubUserRepo{
			findByEmailFn: func(_ context.Context, _ string) (*entity.User, error) { return nil, errMissing },
		},
		&stubSessionStore{},
		&stubTokenSigner{},
	)

	_, err := uc.Login(context.Background(), usecase.LoginInput{
		Email: "nobody@example.com", Password: "any",
	})
	if err == nil || err.Error() != "invalid credentials" {
		t.Fatalf("expected 'invalid credentials', got %v", err)
	}
}

func TestLogin_WrongPassword(t *testing.T) {
	user := buildActiveUser(t, "correct-pass")
	uc := usecase.New(
		&stubUserRepo{
			findByEmailFn: func(_ context.Context, _ string) (*entity.User, error) { return user, nil },
		},
		&stubSessionStore{},
		&stubTokenSigner{},
	)

	_, err := uc.Login(context.Background(), usecase.LoginInput{
		Email: "user@example.com", Password: "wrong-pass",
	})
	if err == nil || err.Error() != "invalid credentials" {
		t.Fatalf("expected 'invalid credentials', got %v", err)
	}
}

func TestLogin_InactiveAccount(t *testing.T) {
	user := buildActiveUser(t, "pass")
	user.Status = entity.StatusSuspended

	uc := usecase.New(
		&stubUserRepo{
			findByEmailFn: func(_ context.Context, _ string) (*entity.User, error) { return user, nil },
		},
		&stubSessionStore{},
		&stubTokenSigner{},
	)

	_, err := uc.Login(context.Background(), usecase.LoginInput{
		Email: "user@example.com", Password: "pass",
	})
	if err == nil {
		t.Fatal("expected error for inactive account")
	}
}

// ── RefreshToken ──────────────────────────────────────────────────────────────

func TestRefreshToken_Success(t *testing.T) {
	userID := uuid.New()
	session := &entity.Session{
		ID:           uuid.New(),
		UserID:       userID,
		RefreshToken: "old-refresh",
		ExpiresAt:    time.Now().Add(time.Hour),
		IsRevoked:    false,
	}
	user := &entity.User{ID: userID, Email: "u@example.com", Status: entity.StatusActive}

	uc := usecase.New(
		&stubUserRepo{
			findByIDFn: func(_ context.Context, _ uuid.UUID) (*entity.User, error) { return user, nil },
		},
		&stubSessionStore{
			findByRefreshTokenFn: func(_ context.Context, _ string) (*entity.Session, error) { return session, nil },
			revokeFn:             noopRevoke,
			saveFn:               noopSave,
		},
		&stubTokenSigner{
			issueFn: func(_ context.Context, _ *entity.User) (*port.TokenPair, error) { return fakeTokens(), nil },
		},
	)

	tokens, err := uc.RefreshToken(context.Background(), "old-refresh")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tokens.RefreshToken == "" {
		t.Error("expected new refresh token")
	}
}

func TestRefreshToken_InvalidToken(t *testing.T) {
	uc := usecase.New(
		&stubUserRepo{},
		&stubSessionStore{
			findByRefreshTokenFn: func(_ context.Context, _ string) (*entity.Session, error) { return nil, errMissing },
		},
		&stubTokenSigner{},
	)

	_, err := uc.RefreshToken(context.Background(), "bad-token")
	if err == nil {
		t.Fatal("expected error for invalid refresh token")
	}
}

func TestRefreshToken_RevokedSession(t *testing.T) {
	session := &entity.Session{
		ID:        uuid.New(),
		UserID:    uuid.New(),
		ExpiresAt: time.Now().Add(time.Hour),
		IsRevoked: true,
	}

	uc := usecase.New(
		&stubUserRepo{},
		&stubSessionStore{
			findByRefreshTokenFn: func(_ context.Context, _ string) (*entity.Session, error) { return session, nil },
		},
		&stubTokenSigner{},
	)

	_, err := uc.RefreshToken(context.Background(), "revoked-token")
	if err == nil {
		t.Fatal("expected error for revoked session")
	}
}

func TestRefreshToken_ExpiredSession(t *testing.T) {
	session := &entity.Session{
		ID:        uuid.New(),
		UserID:    uuid.New(),
		ExpiresAt: time.Now().Add(-time.Hour), // expired
		IsRevoked: false,
	}

	uc := usecase.New(
		&stubUserRepo{},
		&stubSessionStore{
			findByRefreshTokenFn: func(_ context.Context, _ string) (*entity.Session, error) { return session, nil },
		},
		&stubTokenSigner{},
	)

	_, err := uc.RefreshToken(context.Background(), "expired-token")
	if err == nil {
		t.Fatal("expected error for expired session")
	}
}

// ── Logout ────────────────────────────────────────────────────────────────────

func TestLogout_Success(t *testing.T) {
	session := &entity.Session{ID: uuid.New(), UserID: uuid.New()}
	revoked := false

	uc := usecase.New(
		&stubUserRepo{},
		&stubSessionStore{
			findByRefreshTokenFn: func(_ context.Context, _ string) (*entity.Session, error) { return session, nil },
			revokeFn: func(_ context.Context, _ uuid.UUID) error {
				revoked = true
				return nil
			},
		},
		&stubTokenSigner{},
	)

	if err := uc.Logout(context.Background(), "valid-refresh"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !revoked {
		t.Error("expected session to be revoked")
	}
}

func TestLogout_Idempotent(t *testing.T) {
	// Session not found → Logout is idempotent, returns nil.
	uc := usecase.New(
		&stubUserRepo{},
		&stubSessionStore{
			findByRefreshTokenFn: func(_ context.Context, _ string) (*entity.Session, error) { return nil, errMissing },
		},
		&stubTokenSigner{},
	)

	if err := uc.Logout(context.Background(), "gone-token"); err != nil {
		t.Fatalf("expected nil for already-gone session, got: %v", err)
	}
}

// ── Verify ────────────────────────────────────────────────────────────────────

func TestVerify_Delegates(t *testing.T) {
	expected := &entity.User{ID: uuid.New(), Email: "v@example.com"}
	uc := usecase.New(
		&stubUserRepo{},
		&stubSessionStore{},
		&stubTokenSigner{
			verifyFn: func(_ context.Context, _ string) (*entity.User, error) { return expected, nil },
		},
	)

	got, err := uc.Verify(context.Background(), "some-token")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.ID != expected.ID {
		t.Error("unexpected user returned from Verify")
	}
}
