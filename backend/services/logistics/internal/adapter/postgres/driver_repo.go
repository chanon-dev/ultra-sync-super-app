package postgres

import (
	"context"
	"encoding/base64"
	"fmt"
	"strings"
	"time"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DriverRepo struct {
	db *pgxpool.Pool
}

func NewDriverRepo(db *pgxpool.Pool) *DriverRepo {
	return &DriverRepo{db: db}
}

func (r *DriverRepo) Create(ctx context.Context, d *entity.Driver) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO drivers
			(id, user_id, name, phone_number, vehicle_type, license_plate, status, rating, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
	`, d.ID, d.UserID, d.Name, d.PhoneNumber, d.VehicleType, d.LicensePlate,
		d.Status, d.Rating, d.CreatedAt, d.UpdatedAt)
	if err != nil {
		return fmt.Errorf("insert driver: %w", err)
	}
	return nil
}

func (r *DriverRepo) FindByID(ctx context.Context, id uuid.UUID) (*entity.Driver, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, user_id, name, phone_number, vehicle_type, license_plate, status, rating, created_at, updated_at
		FROM drivers WHERE id = $1
	`, id)
	return scanDriver(row)
}

func (r *DriverRepo) FindByUserID(ctx context.Context, userID uuid.UUID) (*entity.Driver, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, user_id, name, phone_number, vehicle_type, license_plate, status, rating, created_at, updated_at
		FROM drivers WHERE user_id = $1
	`, userID)
	return scanDriver(row)
}

func (r *DriverRepo) List(ctx context.Context, status string, limit int, after string) ([]*entity.Driver, string, error) {
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
		cursorTS, cursorID, err := decodeDriverCursor(after)
		if err == nil {
			conditions = append(conditions, fmt.Sprintf(
				"(created_at < $%d OR (created_at = $%d AND id < $%d))",
				argIdx, argIdx+1, argIdx+2,
			))
			args = append(args, cursorTS, cursorTS, cursorID)
			argIdx += 3
		}
	}

	where := ""
	if len(conditions) > 0 {
		where = "WHERE " + strings.Join(conditions, " AND ")
	}

	args = append(args, limit+1)
	query := fmt.Sprintf(`
		SELECT id, user_id, name, phone_number, vehicle_type, license_plate, status, rating, created_at, updated_at
		FROM drivers %s
		ORDER BY created_at DESC, id DESC
		LIMIT $%d
	`, where, argIdx)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, "", fmt.Errorf("list drivers: %w", err)
	}
	defer rows.Close()

	var drivers []*entity.Driver
	for rows.Next() {
		d, err := scanDriver(rows)
		if err != nil {
			return nil, "", err
		}
		drivers = append(drivers, d)
	}
	if err := rows.Err(); err != nil {
		return nil, "", fmt.Errorf("rows error: %w", err)
	}

	var nextCursor string
	if len(drivers) > limit {
		drivers = drivers[:limit]
		last := drivers[len(drivers)-1]
		nextCursor = encodeDriverCursor(last.CreatedAt, last.ID)
	}

	return drivers, nextCursor, nil
}

func (r *DriverRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status entity.DriverStatus) error {
	_, err := r.db.Exec(ctx, `
		UPDATE drivers SET status=$2, updated_at=$3 WHERE id=$1
	`, id, status, time.Now())
	if err != nil {
		return fmt.Errorf("update driver status: %w", err)
	}
	return nil
}

type driverScanner interface {
	Scan(dest ...any) error
}

func scanDriver(row driverScanner) (*entity.Driver, error) {
	d := &entity.Driver{}
	err := row.Scan(
		&d.ID, &d.UserID, &d.Name, &d.PhoneNumber, &d.VehicleType,
		&d.LicensePlate, &d.Status, &d.Rating, &d.CreatedAt, &d.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("scan driver: %w", err)
	}
	return d, nil
}

func encodeDriverCursor(t time.Time, id uuid.UUID) string {
	raw := fmt.Sprintf("%d_%s", t.UnixNano(), id.String())
	return base64.StdEncoding.EncodeToString([]byte(raw))
}

func decodeDriverCursor(cursor string) (time.Time, uuid.UUID, error) {
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
