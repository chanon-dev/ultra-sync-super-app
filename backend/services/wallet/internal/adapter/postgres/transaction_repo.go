package postgres

import (
	"context"
	"encoding/base64"
	"fmt"
	"strings"

	"github.com/chanon/ultra-sync/services/wallet/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/wallet/internal/domain/port"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TransactionRepo struct {
	db *pgxpool.Pool
}

func NewTransactionRepo(db *pgxpool.Pool) *TransactionRepo {
	return &TransactionRepo{db: db}
}

func (r *TransactionRepo) Create(ctx context.Context, tx *entity.Transaction) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO transactions
			(id, wallet_id, type, amount, balance_after, reference_id, idempotency_key, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`, tx.ID, tx.WalletID, tx.Type, tx.Amount, tx.BalanceAfter,
		tx.ReferenceID, tx.IdempotencyKey, tx.CreatedAt)
	if err != nil {
		return fmt.Errorf("insert transaction: %w", err)
	}
	return nil
}

func (r *TransactionRepo) FindByIdempotencyKey(ctx context.Context, key string) (*entity.Transaction, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, wallet_id, type, amount, balance_after, reference_id, idempotency_key, created_at
		FROM transactions WHERE idempotency_key = $1
	`, key)

	tx := &entity.Transaction{}
	if err := row.Scan(
		&tx.ID, &tx.WalletID, &tx.Type,
		&tx.Amount, &tx.BalanceAfter, &tx.ReferenceID,
		&tx.IdempotencyKey, &tx.CreatedAt,
	); err != nil {
		return nil, fmt.Errorf("find transaction: %w", err)
	}
	return tx, nil
}

func (r *TransactionRepo) List(ctx context.Context, q port.ListQuery) ([]*entity.Transaction, string, error) {
	limit := q.Limit
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	conditions := []string{fmt.Sprintf("wallet_id = $1")}
	args := []any{q.WalletID}
	argIdx := 2

	if q.Type != "" {
		conditions = append(conditions, fmt.Sprintf("type = $%d", argIdx))
		args = append(args, q.Type)
		argIdx++
	}

	if q.After != "" {
		raw, err := base64.StdEncoding.DecodeString(q.After)
		if err == nil {
			parts := strings.SplitN(string(raw), "|", 2)
			if len(parts) == 2 {
				conditions = append(conditions, fmt.Sprintf(
					"(created_at < $%d::TIMESTAMPTZ OR (created_at = $%d::TIMESTAMPTZ AND id < $%d::UUID))",
					argIdx, argIdx+1, argIdx+2,
				))
				args = append(args, parts[0], parts[0], parts[1])
				argIdx += 3
			}
		}
	}

	where := "WHERE " + strings.Join(conditions, " AND ")
	args = append(args, limit+1)

	query := fmt.Sprintf(`
		SELECT id, wallet_id, type, amount, balance_after, reference_id, idempotency_key, created_at
		FROM transactions
		%s
		ORDER BY created_at DESC, id DESC
		LIMIT $%d
	`, where, argIdx)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, "", fmt.Errorf("list transactions: %w", err)
	}
	defer rows.Close()

	var txs []*entity.Transaction
	for rows.Next() {
		tx := &entity.Transaction{}
		if err := rows.Scan(
			&tx.ID, &tx.WalletID, &tx.Type,
			&tx.Amount, &tx.BalanceAfter, &tx.ReferenceID,
			&tx.IdempotencyKey, &tx.CreatedAt,
		); err != nil {
			return nil, "", fmt.Errorf("scan transaction row: %w", err)
		}
		txs = append(txs, tx)
	}

	var nextCursor string
	if len(txs) > limit {
		txs = txs[:limit]
		last := txs[len(txs)-1]
		raw := fmt.Sprintf("%s|%s", last.CreatedAt.UTC().Format("2006-01-02T15:04:05.999999999Z07:00"), last.ID)
		nextCursor = base64.StdEncoding.EncodeToString([]byte(raw))
	}

	return txs, nextCursor, nil
}
