package usecase

import (
	"context"
	"fmt"
	"time"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/logistics/internal/domain/port"
	"github.com/google/uuid"
)

type ShipmentUseCase struct {
	repo      port.ShipmentRepository
	logWriter port.ShipmentLogWriter
	cache     port.LocationCache
	events    port.EventPublisher
}

func New(
	repo port.ShipmentRepository,
	logWriter port.ShipmentLogWriter,
	cache port.LocationCache,
	events port.EventPublisher,
) *ShipmentUseCase {
	return &ShipmentUseCase{
		repo:      repo,
		logWriter: logWriter,
		cache:     cache,
		events:    events,
	}
}

type CreateShipmentInput struct {
	SenderID   uuid.UUID
	PickupGeo  entity.GeoPoint
	DropoffGeo entity.GeoPoint
}

func (uc *ShipmentUseCase) CreateShipment(ctx context.Context, in CreateShipmentInput) (*entity.Shipment, error) {
	shipment := &entity.Shipment{
		ID:         uuid.New(),
		OrderNo:    generateOrderNo(),
		SenderID:   in.SenderID,
		Status:     entity.StatusPending,
		PickupGeo:  in.PickupGeo,
		DropoffGeo: in.DropoffGeo,
		Price:      "0.0000",
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}

	if err := uc.repo.Create(ctx, shipment); err != nil {
		return nil, fmt.Errorf("create shipment: %w", err)
	}

	if err := uc.events.PublishShipmentCreated(ctx, shipment); err != nil {
		// Non-fatal: log and continue (Kafka is best-effort for notifications)
		_ = err
	}

	return shipment, nil
}

func (uc *ShipmentUseCase) UpdateLocation(ctx context.Context, shipmentID, driverID uuid.UUID, geo entity.GeoPoint, speedKmH float64) error {
	if err := uc.cache.SetDriverLocation(ctx, driverID, geo); err != nil {
		return fmt.Errorf("set driver location: %w", err)
	}

	log := &entity.ShipmentLog{
		ShipmentID: shipmentID,
		Status:     entity.StatusShipping,
		CurrentGeo: geo,
		SpeedKmH:   speedKmH,
		CreatedAt:  time.Now(),
	}
	return uc.logWriter.Append(ctx, log)
}

func (uc *ShipmentUseCase) AssignDriver(ctx context.Context, shipmentID, driverID uuid.UUID) error {
	if err := uc.repo.AssignDriver(ctx, shipmentID, driverID); err != nil {
		return fmt.Errorf("assign driver: %w", err)
	}
	return uc.repo.UpdateStatus(ctx, shipmentID, entity.StatusAssigned)
}

func (uc *ShipmentUseCase) UpdateStatus(ctx context.Context, id uuid.UUID, status entity.ShipmentStatus) error {
	return uc.repo.UpdateStatus(ctx, id, status)
}

func (uc *ShipmentUseCase) GetShipment(ctx context.Context, id uuid.UUID) (*entity.Shipment, error) {
	s, err := uc.repo.FindByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("find shipment: %w", err)
	}
	return s, nil
}

func (uc *ShipmentUseCase) ListShipments(ctx context.Context, q port.ListQuery) ([]*entity.Shipment, string, error) {
	return uc.repo.List(ctx, q)
}

func generateOrderNo() string {
	return fmt.Sprintf("ORD-%d-%s", time.Now().Year(), uuid.NewString()[:8])
}
