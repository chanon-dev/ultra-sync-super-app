package postgres

import (
	"context"
	"encoding/base64"
	"fmt"
	"strings"
	"time"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/logistics/internal/domain/port"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ShipmentRepo struct {
	db *pgxpool.Pool
}

func NewShipmentRepo(db *pgxpool.Pool) *ShipmentRepo {
	return &ShipmentRepo{db: db}
}

func (r *ShipmentRepo) Create(ctx context.Context, s *entity.Shipment) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO shipments
			(id, order_no, sender_id, driver_id, status,
			 pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
			 price, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
	`,
		s.ID, s.OrderNo, s.SenderID, s.DriverID, s.Status,
		s.PickupGeo.Latitude, s.PickupGeo.Longitude,
		s.DropoffGeo.Latitude, s.DropoffGeo.Longitude,
		s.Price, s.CreatedAt, s.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("insert shipment: %w", err)
	}
	return nil
}

func (r *ShipmentRepo) FindByID(ctx context.Context, id uuid.UUID) (*entity.Shipment, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, order_no, sender_id, driver_id, status,
		       pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
		       price, created_at, updated_at
		FROM shipments WHERE id = $1
	`, id)

	s := &entity.Shipment{}
	err := row.Scan(
		&s.ID, &s.OrderNo, &s.SenderID, &s.DriverID, &s.Status,
		&s.PickupGeo.Latitude, &s.PickupGeo.Longitude,
		&s.DropoffGeo.Latitude, &s.DropoffGeo.Longitude,
		&s.Price, &s.CreatedAt, &s.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("scan shipment: %w", err)
	}
	return s, nil
}

func (r *ShipmentRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status entity.ShipmentStatus) error {
	_, err := r.db.Exec(ctx, `
		UPDATE shipments SET status=$2, updated_at=$3 WHERE id=$1
	`, id, status, time.Now())
	if err != nil {
		return fmt.Errorf("update shipment status: %w", err)
	}
	return nil
}

func (r *ShipmentRepo) AssignDriver(ctx context.Context, shipmentID, driverID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		UPDATE shipments SET driver_id=$2, updated_at=$3 WHERE id=$1
	`, shipmentID, driverID, time.Now())
	if err != nil {
		return fmt.Errorf("assign driver: %w", err)
	}
	return nil
}

// List returns a page of shipments using cursor-based pagination (created_at DESC, id DESC).
func (r *ShipmentRepo) List(ctx context.Context, q port.ListQuery) ([]*entity.Shipment, string, error) {
	limit := q.Limit
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	var (
		conditions []string
		args       []any
		argIdx     = 1
	)

	if q.SenderID != "" {
		conditions = append(conditions, fmt.Sprintf("sender_id = $%d", argIdx))
		args = append(args, q.SenderID)
		argIdx++
	}
	if q.Status != "" {
		conditions = append(conditions, fmt.Sprintf("status = $%d", argIdx))
		args = append(args, q.Status)
		argIdx++
	}

	if q.After != "" {
		cursorTS, cursorID, err := decodeCursor(q.After)
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
		SELECT id, order_no, sender_id, driver_id, status,
		       pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
		       price, created_at, updated_at
		FROM shipments
		%s
		ORDER BY created_at DESC, id DESC
		LIMIT $%d
	`, where, argIdx)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, "", fmt.Errorf("list shipments: %w", err)
	}
	defer rows.Close()

	var shipments []*entity.Shipment
	for rows.Next() {
		s := &entity.Shipment{}
		if err := rows.Scan(
			&s.ID, &s.OrderNo, &s.SenderID, &s.DriverID, &s.Status,
			&s.PickupGeo.Latitude, &s.PickupGeo.Longitude,
			&s.DropoffGeo.Latitude, &s.DropoffGeo.Longitude,
			&s.Price, &s.CreatedAt, &s.UpdatedAt,
		); err != nil {
			return nil, "", fmt.Errorf("scan shipment row: %w", err)
		}
		shipments = append(shipments, s)
	}

	var nextCursor string
	if len(shipments) > limit {
		shipments = shipments[:limit]
		last := shipments[len(shipments)-1]
		nextCursor = encodeCursor(last.CreatedAt, last.ID)
	}

	return shipments, nextCursor, nil
}

func encodeCursor(t time.Time, id uuid.UUID) string {
	raw := fmt.Sprintf("%d_%s", t.UnixNano(), id.String())
	return base64.StdEncoding.EncodeToString([]byte(raw))
}

func decodeCursor(cursor string) (time.Time, uuid.UUID, error) {
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
	id, err := uuid.Parse(parts[1])
	if err != nil {
		return time.Time{}, uuid.Nil, fmt.Errorf("invalid cursor id: %w", err)
	}
	return time.Unix(0, nanos), id, nil
}
