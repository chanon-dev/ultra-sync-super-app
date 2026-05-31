package port

import (
	"context"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/google/uuid"
)

type ShipmentRepository interface {
	Create(ctx context.Context, s *entity.Shipment) error
	FindByID(ctx context.Context, id uuid.UUID) (*entity.Shipment, error)
	FindByIdempotencyKey(ctx context.Context, key string) (*entity.Shipment, error)
	UpdateStatus(ctx context.Context, id uuid.UUID, status entity.ShipmentStatus) error
	AssignDriver(ctx context.Context, shipmentID, driverID uuid.UUID) error
	List(ctx context.Context, q ListQuery) ([]*entity.Shipment, string, error)
}

type ListQuery struct {
	SenderID string
	Status   string
	After    string // cursor (base64-encoded created_at+id)
	Limit    int
}

type LocationCache interface {
	SetDriverLocation(ctx context.Context, driverID uuid.UUID, geo entity.GeoPoint) error
	GetDriverLocation(ctx context.Context, driverID uuid.UUID) (*entity.GeoPoint, error)
}

type ShipmentLogWriter interface {
	Append(ctx context.Context, log *entity.ShipmentLog) error
}

type ShipmentLogReader interface {
	GetRoute(ctx context.Context, shipmentID uuid.UUID, limit int, afterID int64) ([]*entity.ShipmentLog, int64, error)
}

type DriverRepository interface {
	Create(ctx context.Context, d *entity.Driver) error
	FindByID(ctx context.Context, id uuid.UUID) (*entity.Driver, error)
	FindByUserID(ctx context.Context, userID uuid.UUID) (*entity.Driver, error)
	List(ctx context.Context, status string, limit int, after string) ([]*entity.Driver, string, error)
	UpdateStatus(ctx context.Context, id uuid.UUID, status entity.DriverStatus) error
}

type EventPublisher interface {
	PublishShipmentCreated(ctx context.Context, shipment *entity.Shipment) error
	PublishStatusUpdated(ctx context.Context, shipmentID uuid.UUID, status entity.ShipmentStatus) error
}
