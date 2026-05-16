package usecase_test

import (
	"context"
	"errors"
	"testing"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/logistics/internal/domain/port"
	"github.com/chanon/ultra-sync/services/logistics/internal/usecase"
	"github.com/google/uuid"
)

// ── Mocks ─────────────────────────────────────────────────────────────────────

type stubShipmentRepo struct {
	createFn         func(ctx context.Context, s *entity.Shipment) error
	findByIDFn       func(ctx context.Context, id uuid.UUID) (*entity.Shipment, error)
	updateStatusFn   func(ctx context.Context, id uuid.UUID, status entity.ShipmentStatus) error
	assignDriverFn   func(ctx context.Context, shipmentID, driverID uuid.UUID) error
	listFn           func(ctx context.Context, q port.ListQuery) ([]*entity.Shipment, string, error)
}

func (s *stubShipmentRepo) Create(ctx context.Context, sh *entity.Shipment) error {
	return s.createFn(ctx, sh)
}
func (s *stubShipmentRepo) FindByID(ctx context.Context, id uuid.UUID) (*entity.Shipment, error) {
	return s.findByIDFn(ctx, id)
}
func (s *stubShipmentRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status entity.ShipmentStatus) error {
	return s.updateStatusFn(ctx, id, status)
}
func (s *stubShipmentRepo) AssignDriver(ctx context.Context, shipmentID, driverID uuid.UUID) error {
	return s.assignDriverFn(ctx, shipmentID, driverID)
}
func (s *stubShipmentRepo) List(ctx context.Context, q port.ListQuery) ([]*entity.Shipment, string, error) {
	return s.listFn(ctx, q)
}

type stubLogWriter struct {
	appendFn func(ctx context.Context, log *entity.ShipmentLog) error
}

func (s *stubLogWriter) Append(ctx context.Context, log *entity.ShipmentLog) error {
	return s.appendFn(ctx, log)
}

type stubLocationCache struct {
	setFn func(ctx context.Context, driverID uuid.UUID, geo entity.GeoPoint) error
	getFn func(ctx context.Context, driverID uuid.UUID) (*entity.GeoPoint, error)
}

func (s *stubLocationCache) SetDriverLocation(ctx context.Context, driverID uuid.UUID, geo entity.GeoPoint) error {
	return s.setFn(ctx, driverID, geo)
}
func (s *stubLocationCache) GetDriverLocation(ctx context.Context, driverID uuid.UUID) (*entity.GeoPoint, error) {
	return s.getFn(ctx, driverID)
}

type stubEventPublisher struct {
	publishCreatedFn func(ctx context.Context, s *entity.Shipment) error
	publishStatusFn  func(ctx context.Context, id uuid.UUID, status entity.ShipmentStatus) error
}

func (s *stubEventPublisher) PublishShipmentCreated(ctx context.Context, sh *entity.Shipment) error {
	return s.publishCreatedFn(ctx, sh)
}
func (s *stubEventPublisher) PublishStatusUpdated(ctx context.Context, id uuid.UUID, status entity.ShipmentStatus) error {
	return s.publishStatusFn(ctx, id, status)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

var errDB = errors.New("db error")

func noopPublisher() *stubEventPublisher {
	return &stubEventPublisher{
		publishCreatedFn: func(_ context.Context, _ *entity.Shipment) error { return nil },
		publishStatusFn:  func(_ context.Context, _ uuid.UUID, _ entity.ShipmentStatus) error { return nil },
	}
}

func geo(lat, lng float64) entity.GeoPoint { return entity.GeoPoint{Latitude: lat, Longitude: lng} }

// ── CreateShipment ────────────────────────────────────────────────────────────

func TestCreateShipment_Success(t *testing.T) {
	senderID := uuid.New()
	uc := usecase.New(
		&stubShipmentRepo{
			createFn: func(_ context.Context, _ *entity.Shipment) error { return nil },
		},
		&stubLogWriter{},
		&stubLocationCache{},
		noopPublisher(), nil,
	)

	s, err := uc.CreateShipment(context.Background(), usecase.CreateShipmentInput{
		SenderID:   senderID,
		PickupGeo:  geo(13.7, 100.5),
		DropoffGeo: geo(13.8, 100.6),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if s.SenderID != senderID {
		t.Errorf("expected senderID %s, got %s", senderID, s.SenderID)
	}
	if s.Status != entity.StatusPending {
		t.Errorf("expected StatusPending, got %s", s.Status)
	}
	if s.OrderNo == "" {
		t.Error("expected non-empty OrderNo")
	}
}

func TestCreateShipment_RepoError(t *testing.T) {
	uc := usecase.New(
		&stubShipmentRepo{
			createFn: func(_ context.Context, _ *entity.Shipment) error { return errDB },
		},
		&stubLogWriter{},
		&stubLocationCache{},
		noopPublisher(), nil,
	)

	_, err := uc.CreateShipment(context.Background(), usecase.CreateShipmentInput{
		SenderID:   uuid.New(),
		PickupGeo:  geo(13.7, 100.5),
		DropoffGeo: geo(13.8, 100.6),
	})
	if err == nil {
		t.Fatal("expected error when repo fails")
	}
}

func TestCreateShipment_EventPublishFailureNonFatal(t *testing.T) {
	// Event publish error must not fail CreateShipment.
	uc := usecase.New(
		&stubShipmentRepo{
			createFn: func(_ context.Context, _ *entity.Shipment) error { return nil },
		},
		&stubLogWriter{},
		&stubLocationCache{},
		&stubEventPublisher{
			publishCreatedFn: func(_ context.Context, _ *entity.Shipment) error { return errors.New("kafka down") },
			publishStatusFn:  func(_ context.Context, _ uuid.UUID, _ entity.ShipmentStatus) error { return nil },
		},
		nil,
	)

	_, err := uc.CreateShipment(context.Background(), usecase.CreateShipmentInput{
		SenderID: uuid.New(), PickupGeo: geo(1, 1), DropoffGeo: geo(2, 2),
	})
	if err != nil {
		t.Fatalf("event publish error must be non-fatal, got: %v", err)
	}
}

// ── AssignDriver ──────────────────────────────────────────────────────────────

func TestAssignDriver_Success(t *testing.T) {
	shipmentID := uuid.New()
	driverID := uuid.New()
	statusSet := entity.ShipmentStatus("")

	uc := usecase.New(
		&stubShipmentRepo{
			assignDriverFn: func(_ context.Context, _, _ uuid.UUID) error { return nil },
			updateStatusFn: func(_ context.Context, _ uuid.UUID, s entity.ShipmentStatus) error {
				statusSet = s
				return nil
			},
		},
		&stubLogWriter{},
		&stubLocationCache{},
		noopPublisher(), nil,
	)

	if err := uc.AssignDriver(context.Background(), shipmentID, driverID); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if statusSet != entity.StatusAssigned {
		t.Errorf("expected StatusAssigned, got %s", statusSet)
	}
}

func TestAssignDriver_RepoError(t *testing.T) {
	uc := usecase.New(
		&stubShipmentRepo{
			assignDriverFn: func(_ context.Context, _, _ uuid.UUID) error { return errDB },
		},
		&stubLogWriter{},
		&stubLocationCache{},
		noopPublisher(), nil,
	)

	err := uc.AssignDriver(context.Background(), uuid.New(), uuid.New())
	if err == nil {
		t.Fatal("expected error from repo")
	}
}

// ── UpdateLocation ────────────────────────────────────────────────────────────

func TestUpdateLocation_Success(t *testing.T) {
	logged := false
	uc := usecase.New(
		&stubShipmentRepo{},
		&stubLogWriter{
			appendFn: func(_ context.Context, _ *entity.ShipmentLog) error {
				logged = true
				return nil
			},
		},
		&stubLocationCache{
			setFn: func(_ context.Context, _ uuid.UUID, _ entity.GeoPoint) error { return nil },
		},
		noopPublisher(), nil,
	)

	err := uc.UpdateLocation(context.Background(), uuid.New(), uuid.New(), geo(13.7, 100.5), 60.0)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !logged {
		t.Error("expected ShipmentLog to be appended")
	}
}

func TestUpdateLocation_CacheError(t *testing.T) {
	uc := usecase.New(
		&stubShipmentRepo{},
		&stubLogWriter{},
		&stubLocationCache{
			setFn: func(_ context.Context, _ uuid.UUID, _ entity.GeoPoint) error { return errDB },
		},
		noopPublisher(), nil,
	)

	err := uc.UpdateLocation(context.Background(), uuid.New(), uuid.New(), geo(1, 1), 0)
	if err == nil {
		t.Fatal("expected error when cache fails")
	}
}

// ── GetShipment ───────────────────────────────────────────────────────────────

func TestGetShipment_Success(t *testing.T) {
	id := uuid.New()
	expected := &entity.Shipment{ID: id, OrderNo: "ORD-2024-abc", Status: entity.StatusPending}

	uc := usecase.New(
		&stubShipmentRepo{
			findByIDFn: func(_ context.Context, _ uuid.UUID) (*entity.Shipment, error) { return expected, nil },
		},
		&stubLogWriter{},
		&stubLocationCache{},
		noopPublisher(), nil,
	)

	got, err := uc.GetShipment(context.Background(), id)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.ID != id {
		t.Errorf("expected ID %s, got %s", id, got.ID)
	}
}

func TestGetShipment_NotFound(t *testing.T) {
	uc := usecase.New(
		&stubShipmentRepo{
			findByIDFn: func(_ context.Context, _ uuid.UUID) (*entity.Shipment, error) { return nil, errDB },
		},
		&stubLogWriter{},
		&stubLocationCache{},
		noopPublisher(), nil,
	)

	_, err := uc.GetShipment(context.Background(), uuid.New())
	if err == nil {
		t.Fatal("expected error for missing shipment")
	}
}

// ── UpdateStatus ──────────────────────────────────────────────────────────────

func TestUpdateStatus_Success(t *testing.T) {
	called := false
	uc := usecase.New(
		&stubShipmentRepo{
			updateStatusFn: func(_ context.Context, _ uuid.UUID, _ entity.ShipmentStatus) error {
				called = true
				return nil
			},
		},
		&stubLogWriter{},
		&stubLocationCache{},
		noopPublisher(), nil,
	)

	if err := uc.UpdateStatus(context.Background(), uuid.New(), entity.StatusDelivered); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !called {
		t.Error("expected UpdateStatus to be called on repo")
	}
}

// ── ListShipments ─────────────────────────────────────────────────────────────

func TestListShipments_ReturnsList(t *testing.T) {
	shipments := []*entity.Shipment{
		{ID: uuid.New(), Status: entity.StatusPending},
		{ID: uuid.New(), Status: entity.StatusAssigned},
	}

	uc := usecase.New(
		&stubShipmentRepo{
			listFn: func(_ context.Context, _ port.ListQuery) ([]*entity.Shipment, string, error) {
				return shipments, "", nil
			},
		},
		&stubLogWriter{},
		&stubLocationCache{},
		noopPublisher(), nil,
	)

	got, _, err := uc.ListShipments(context.Background(), port.ListQuery{Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got) != 2 {
		t.Errorf("expected 2 shipments, got %d", len(got))
	}
}
