package port

import (
	"context"

	"github.com/chanon/ultra-sync/services/wallet/internal/domain/entity"
	"github.com/google/uuid"
)

type WalletRepository interface {
	FindByUserID(ctx context.Context, userID uuid.UUID) (*entity.Wallet, error)
	// CreditWithLock applies amount using optimistic locking (version column).
	// Returns ErrVersionConflict on concurrent modification — caller must retry.
	CreditWithLock(ctx context.Context, userID uuid.UUID, amount string, version int) error
	DebitWithLock(ctx context.Context, userID uuid.UUID, amount string, version int) error
	Create(ctx context.Context, wallet *entity.Wallet) error
}

type TransactionRepository interface {
	Create(ctx context.Context, tx *entity.Transaction) error
	FindByIdempotencyKey(ctx context.Context, key string) (*entity.Transaction, error)
	List(ctx context.Context, q ListQuery) ([]*entity.Transaction, string, error)
}

type ListQuery struct {
	WalletID uuid.UUID
	Type     string
	After    string
	Limit    int
}
