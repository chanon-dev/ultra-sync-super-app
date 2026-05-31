package usecase

import (
	"context"
	"fmt"
	"time"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/logistics/internal/domain/port"
	"github.com/google/uuid"
)

// validTransitions defines which status changes are allowed.
var validTransitions = map[entity.ShipmentStatus][]entity.ShipmentStatus{
	entity.StatusPending:   {entity.StatusAssigned, entity.StatusCancelled},
	entity.StatusAssigned:  {entity.StatusPickedUp, entity.StatusCancelled},
	entity.StatusPickedUp:  {entity.StatusShipping, entity.StatusCancelled},
	entity.StatusShipping:  {entity.StatusDelivered, entity.StatusCancelled},
	entity.StatusDelivered: {},
	entity.StatusCancelled: {},
}

type ShipmentUseCase struct {
	repo      port.ShipmentRepository
	logWriter port.ShipmentLogWriter
	logReader port.ShipmentLogReader
	cache     port.LocationCache
	events    port.EventPublisher
	wallet    port.WalletClient
	notifier  port.PushNotifier
}

func New(
	repo port.ShipmentRepository,
	logWriter port.ShipmentLogWriter,
	logReader port.ShipmentLogReader,
	cache port.LocationCache,
	events port.EventPublisher,
	wallet port.WalletClient,
	notifier port.PushNotifier,
) *ShipmentUseCase {
	return &ShipmentUseCase{
		repo:      repo,
		logWriter: logWriter,
		logReader: logReader,
		cache:     cache,
		events:    events,
		wallet:    wallet,
		notifier:  notifier,
	}
}

type CreateShipmentInput struct {
	SenderID       uuid.UUID
	PickupGeo      entity.GeoPoint
	DropoffGeo     entity.GeoPoint
	IdempotencyKey string
}

func (uc *ShipmentUseCase) CreateShipment(ctx context.Context, in CreateShipmentInput) (*entity.Shipment, error) {
	if in.IdempotencyKey != "" {
		if existing, err := uc.repo.FindByIdempotencyKey(ctx, in.IdempotencyKey); err == nil {
			return existing, nil
		}
	}

	shipment := &entity.Shipment{
		ID:             uuid.New(),
		OrderNo:        generateOrderNo(),
		SenderID:       in.SenderID,
		Status:         entity.StatusPending,
		PickupGeo:      in.PickupGeo,
		DropoffGeo:     in.DropoffGeo,
		Price:          "0.0000",
		IdempotencyKey: in.IdempotencyKey,
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
	}

	if err := uc.repo.Create(ctx, shipment); err != nil {
		return nil, fmt.Errorf("create shipment: %w", err)
	}

	if err := uc.events.PublishShipmentCreated(ctx, shipment); err != nil {
		_ = err // non-fatal
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
	shipment, err := uc.repo.FindByID(ctx, id)
	if err != nil {
		return fmt.Errorf("find shipment: %w", err)
	}

	if !isValidTransition(shipment.Status, status) {
		return fmt.Errorf("invalid transition: %s → %s", shipment.Status, status)
	}

	if err := uc.repo.UpdateStatus(ctx, id, status); err != nil {
		return err
	}

	if err := uc.events.PublishStatusUpdated(ctx, id, status); err != nil {
		_ = err // non-fatal
	}

	if uc.notifier != nil {
		_ = uc.notifier.NotifyShipmentStatusChange(ctx, shipment.SenderID, id, status)
	}

	if status == entity.StatusDelivered && uc.wallet != nil {
		idempotencyKey := fmt.Sprintf("delivery-%s", id.String())
		if err := uc.wallet.ChargeForDelivery(ctx, id, shipment.SenderID, shipment.Price, idempotencyKey); err != nil {
			_ = err // non-fatal in dev
		}
	}

	return nil
}

func (uc *ShipmentUseCase) CancelShipment(ctx context.Context, id, requesterID uuid.UUID) error {
	shipment, err := uc.repo.FindByID(ctx, id)
	if err != nil {
		return fmt.Errorf("find shipment: %w", err)
	}
	if shipment.SenderID != requesterID {
		return fmt.Errorf("only the sender can cancel a shipment")
	}
	if !isValidTransition(shipment.Status, entity.StatusCancelled) {
		return fmt.Errorf("cannot cancel shipment in status: %s", shipment.Status)
	}
	return uc.UpdateStatus(ctx, id, entity.StatusCancelled)
}

func (uc *ShipmentUseCase) GetRoute(ctx context.Context, shipmentID uuid.UUID, limit int, afterID int64) ([]*entity.ShipmentLog, int64, error) {
	if uc.logReader == nil {
		return nil, 0, fmt.Errorf("route history not available")
	}
	return uc.logReader.GetRoute(ctx, shipmentID, limit, afterID)
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

func isValidTransition(from, to entity.ShipmentStatus) bool {
	allowed, ok := validTransitions[from]
	if !ok {
		return false
	}
	for _, s := range allowed {
		if s == to {
			return true
		}
	}
	return false
}

func generateOrderNo() string {
	return fmt.Sprintf("ORD-%d-%s", time.Now().Year(), uuid.NewString()[:8])
}
