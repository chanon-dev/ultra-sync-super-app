package postgres

import (
	"context"
	"fmt"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
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
