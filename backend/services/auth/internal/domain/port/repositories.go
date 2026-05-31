package port

import (
	"context"

	"github.com/chanon/ultra-sync/services/auth/internal/domain/entity"
	"github.com/google/uuid"
)

type UserRepository interface {
	Create(ctx context.Context, user *entity.User) error
	FindByID(ctx context.Context, id uuid.UUID) (*entity.User, error)
	FindByEmail(ctx context.Context, email string) (*entity.User, error)
	Update(ctx context.Context, user *entity.User) error
	ListUsers(ctx context.Context, status string, limit int, after string) ([]*entity.User, string, error)
	UpdateStatus(ctx context.Context, userID uuid.UUID, status entity.UserStatus) error
}

type SessionStorer interface {
	Save(ctx context.Context, session *entity.Session) error
	FindByRefreshToken(ctx context.Context, token string) (*entity.Session, error)
	Revoke(ctx context.Context, sessionID uuid.UUID) error
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
}

type TokenSigner interface {
	Issue(ctx context.Context, user *entity.User) (*TokenPair, error)
	Verify(ctx context.Context, accessToken string) (*entity.User, error)
}
