package postgres

import (
	"context"
	"encoding/base64"
	"fmt"
	"strings"
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
		INSERT INTO users
			(id, email, password_hash, display_name, avatar_url, role, status, mfa_secret, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`, user.ID, user.Email, user.PasswordHash, user.DisplayName, user.AvatarURL,
		user.Role, user.Status, user.MFASecret, user.CreatedAt, user.UpdatedAt)
	if err != nil {
		return fmt.Errorf("insert user: %w", err)
	}
	return nil
}

func (r *UserRepo) FindByID(ctx context.Context, id uuid.UUID) (*entity.User, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, email, password_hash, display_name, avatar_url,
		       role, status, mfa_secret, last_login_at, created_at, updated_at
		FROM users WHERE id = $1
	`, id)
	return scanUser(row)
}

func (r *UserRepo) FindByEmail(ctx context.Context, email string) (*entity.User, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, email, password_hash, display_name, avatar_url,
		       role, status, mfa_secret, last_login_at, created_at, updated_at
		FROM users WHERE email = $1
	`, email)
	return scanUser(row)
}

func (r *UserRepo) Update(ctx context.Context, user *entity.User) error {
	user.UpdatedAt = time.Now()
	_, err := r.db.Exec(ctx, `
		UPDATE users
		SET display_name=$2, avatar_url=$3, role=$4, status=$5,
		    mfa_secret=$6, last_login_at=$7, updated_at=$8
		WHERE id=$1
	`, user.ID, user.DisplayName, user.AvatarURL, user.Role, user.Status,
		user.MFASecret, user.LastLoginAt, user.UpdatedAt)
	if err != nil {
		return fmt.Errorf("update user: %w", err)
	}
	return nil
}

func (r *UserRepo) ListUsers(ctx context.Context, status string, limit int, after string) ([]*entity.User, string, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	var conditions []string
	var args []any
	argIdx := 1

	if status != "" {
		conditions = append(conditions, fmt.Sprintf("status = $%d", argIdx))
		args = append(args, status)
		argIdx++
	}

	if after != "" {
		cursorTime, cursorID, err := decodeUserCursor(after)
		if err == nil {
			conditions = append(conditions, fmt.Sprintf(
				"(created_at < $%d OR (created_at = $%d AND id < $%d))",
				argIdx, argIdx+1, argIdx+2,
			))
			args = append(args, cursorTime, cursorTime, cursorID)
			argIdx += 3
		}
	}

	where := ""
	if len(conditions) > 0 {
		where = "WHERE " + strings.Join(conditions, " AND ")
	}

	args = append(args, limit+1)
	query := fmt.Sprintf(`
		SELECT id, email, password_hash, display_name, avatar_url,
		       role, status, mfa_secret, last_login_at, created_at, updated_at
		FROM users %s
		ORDER BY created_at DESC, id DESC
		LIMIT $%d
	`, where, argIdx)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, "", fmt.Errorf("list users: %w", err)
	}
	defer rows.Close()

	var users []*entity.User
	for rows.Next() {
		u, err := scanUser(rows)
		if err != nil {
			return nil, "", err
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return nil, "", fmt.Errorf("rows error: %w", err)
	}

	var nextCursor string
	if len(users) > limit {
		users = users[:limit]
		last := users[len(users)-1]
		nextCursor = encodeUserCursor(last.CreatedAt, last.ID)
	}

	return users, nextCursor, nil
}

func (r *UserRepo) UpdateStatus(ctx context.Context, userID uuid.UUID, status entity.UserStatus) error {
	_, err := r.db.Exec(ctx, `
		UPDATE users SET status=$2, updated_at=$3 WHERE id=$1
	`, userID, status, time.Now())
	if err != nil {
		return fmt.Errorf("update user status: %w", err)
	}
	return nil
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanUser(row rowScanner) (*entity.User, error) {
	u := &entity.User{}
	err := row.Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.DisplayName, &u.AvatarURL,
		&u.Role, &u.Status, &u.MFASecret, &u.LastLoginAt, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("scan user: %w", err)
	}
	return u, nil
}

func encodeUserCursor(t time.Time, id uuid.UUID) string {
	raw := fmt.Sprintf("%d_%s", t.UnixNano(), id.String())
	return base64.StdEncoding.EncodeToString([]byte(raw))
}

func decodeUserCursor(cursor string) (time.Time, uuid.UUID, error) {
	b, err := base64.StdEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, uuid.Nil, fmt.Errorf("decode cursor: %w", err)
	}
	parts := strings.SplitN(string(b), "_", 2)
	if len(parts) != 2 {
		return time.Time{}, uuid.Nil, fmt.Errorf("invalid cursor format")
	}
	var nanos int64
	if _, err := fmt.Sscanf(parts[0], "%d", &nanos); err != nil {
		return time.Time{}, uuid.Nil, fmt.Errorf("invalid cursor timestamp: %w", err)
	}
	uid, err := uuid.Parse(parts[1])
	if err != nil {
		return time.Time{}, uuid.Nil, fmt.Errorf("invalid cursor id: %w", err)
	}
	return time.Unix(0, nanos), uid, nil
}
