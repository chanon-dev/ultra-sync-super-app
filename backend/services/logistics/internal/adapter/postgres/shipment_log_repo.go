package postgres

import (
	"context"
	"fmt"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ShipmentLogRepo struct {
	db *pgxpool.Pool
}

func NewShipmentLogRepo(db *pgxpool.Pool) *ShipmentLogRepo {
	return &ShipmentLogRepo{db: db}
}

func (r *ShipmentLogRepo) Append(ctx context.Context, log *entity.ShipmentLog) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO shipment_logs
			(shipment_id, status, current_lat, current_lng, speed_kmh, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`,
		log.ShipmentID, log.Status,
		log.CurrentGeo.Latitude, log.CurrentGeo.Longitude,
		log.SpeedKmH, log.CreatedAt,
	)
	if err != nil {
		return fmt.Errorf("append shipment log: %w", err)
	}
	return nil
}

func (r *ShipmentLogRepo) GetRoute(ctx context.Context, shipmentID uuid.UUID, limit int, afterID int64) ([]*entity.ShipmentLog, int64, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	rows, err := r.db.Query(ctx, `
		SELECT id, shipment_id, status, current_lat, current_lng, speed_kmh, created_at
		FROM shipment_logs
		WHERE shipment_id = $1 AND id > $2
		ORDER BY id ASC
		LIMIT $3
	`, shipmentID, afterID, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("query route: %w", err)
	}
	defer rows.Close()

	var logs []*entity.ShipmentLog
	var lastID int64
	for rows.Next() {
		l := &entity.ShipmentLog{}
		if err := rows.Scan(
			&l.ID, &l.ShipmentID, &l.Status,
			&l.CurrentGeo.Latitude, &l.CurrentGeo.Longitude,
			&l.SpeedKmH, &l.CreatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("scan log: %w", err)
		}
		lastID = l.ID
		logs = append(logs, l)
	}
	return logs, lastID, rows.Err()
}
