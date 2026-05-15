package postgres

import (
	"context"
	"fmt"
	"time"

	"github.com/chanon/ultra-sync/services/auth/internal/domain/entity"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserRepo struct {
	db *pgxpool.Pool
}

func NewUserRepo(db *pgxpool.Pool) *UserRepo {
	return &UserRepo{db: db}
}

func (r *UserRepo) Create(ctx context.Context, user *entity.User) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, role, status, mfa_secret, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`, user.ID, user.Email, user.PasswordHash, user.Role, user.Status,
		user.MFASecret, user.CreatedAt, user.UpdatedAt)
	if err != nil {
		return fmt.Errorf("insert user: %w", err)
	}
	return nil
}

func (r *UserRepo) FindByID(ctx context.Context, id uuid.UUID) (*entity.User, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, email, password_hash, role, status, mfa_secret, last_login_at, created_at, updated_at
		FROM users WHERE id = $1
	`, id)
	return scanUser(row)
}

func (r *UserRepo) FindByEmail(ctx context.Context, email string) (*entity.User, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, email, password_hash, role, status, mfa_secret, last_login_at, created_at, updated_at
		FROM users WHERE email = $1
	`, email)
	return scanUser(row)
}

func (r *UserRepo) Update(ctx context.Context, user *entity.User) error {
	user.UpdatedAt = time.Now()
	_, err := r.db.Exec(ctx, `
		UPDATE users
		SET role=$2, status=$3, mfa_secret=$4, last_login_at=$5, updated_at=$6
		WHERE id=$1
	`, user.ID, user.Role, user.Status, user.MFASecret, user.LastLoginAt, user.UpdatedAt)
	if err != nil {
		return fmt.Errorf("update user: %w", err)
	}
	return nil
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanUser(row rowScanner) (*entity.User, error) {
	u := &entity.User{}
	err := row.Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.Role, &u.Status,
		&u.MFASecret, &u.LastLoginAt, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("scan user: %w", err)
	}
	return u, nil
}
