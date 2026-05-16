package postgres

import (
	"context"
	"fmt"
	"time"

	"github.com/chanon/ultra-sync/services/wallet/internal/domain/entity"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrVersionConflict = fmt.Errorf("optimistic lock version conflict")

type WalletRepo struct {
	db *pgxpool.Pool
}

func NewWalletRepo(db *pgxpool.Pool) *WalletRepo {
	return &WalletRepo{db: db}
}

func (r *WalletRepo) FindByUserID(ctx context.Context, userID uuid.UUID) (*entity.Wallet, error) {
	row := r.db.QueryRow(ctx, `
		SELECT user_id, balance, currency, version, updated_at
		FROM wallets WHERE user_id = $1
	`, userID)

	w := &entity.Wallet{}
	if err := row.Scan(&w.UserID, &w.Balance, &w.Currency, &w.Version, &w.UpdatedAt); err != nil {
		return nil, fmt.Errorf("find wallet: %w", err)
	}
	return w, nil
}

func (r *WalletRepo) Create(ctx context.Context, w *entity.Wallet) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO wallets (user_id, balance, currency, version, updated_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id) DO NOTHING
	`, w.UserID, w.Balance, w.Currency, w.Version, w.UpdatedAt)
	if err != nil {
		return fmt.Errorf("create wallet: %w", err)
	}
	return nil
}

func (r *WalletRepo) CreditWithLock(ctx context.Context, userID uuid.UUID, amount string, version int) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE wallets
		SET balance    = balance + $2::DECIMAL(20,4),
		    version    = version + 1,
		    updated_at = $3
		WHERE user_id = $1 AND version = $4
	`, userID, amount, time.Now(), version)
	if err != nil {
		return fmt.Errorf("credit wallet: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrVersionConflict
	}
	return nil
}

func (r *WalletRepo) DebitWithLock(ctx context.Context, userID uuid.UUID, amount string, version int) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE wallets
		SET balance    = balance - $2::DECIMAL(20,4),
		    version    = version + 1,
		    updated_at = $3
		WHERE user_id = $1 AND version = $4 AND balance >= $2::DECIMAL(20,4)
	`, userID, amount, time.Now(), version)
	if err != nil {
		return fmt.Errorf("debit wallet: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrVersionConflict
	}
	return nil
}
