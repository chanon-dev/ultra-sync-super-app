package usecase

import (
	"context"
	"fmt"
	"time"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/logistics/internal/domain/port"
	"github.com/google/uuid"
)

type DriverUseCase struct {
	repo port.DriverRepository
}

func NewDriverUseCase(repo port.DriverRepository) *DriverUseCase {
	return &DriverUseCase{repo: repo}
}

type RegisterDriverInput struct {
	UserID       uuid.UUID
	Name         string
	PhoneNumber  string
	VehicleType  string
	LicensePlate string
}

func (uc *DriverUseCase) RegisterDriver(ctx context.Context, in RegisterDriverInput) (*entity.Driver, error) {
	if in.UserID == uuid.Nil {
		return nil, fmt.Errorf("user id required")
	}
	if in.Name == "" {
		return nil, fmt.Errorf("name required")
	}
	d := &entity.Driver{
		ID:           uuid.New(),
		UserID:       in.UserID,
		Name:         in.Name,
		PhoneNumber:  in.PhoneNumber,
		VehicleType:  in.VehicleType,
		LicensePlate: in.LicensePlate,
		Status:       entity.DriverStatusActive,
		Rating:       5.0,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}
	if err := uc.repo.Create(ctx, d); err != nil {
		return nil, fmt.Errorf("register driver: %w", err)
	}
	return d, nil
}

func (uc *DriverUseCase) GetDriver(ctx context.Context, id uuid.UUID) (*entity.Driver, error) {
	d, err := uc.repo.FindByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("find driver: %w", err)
	}
	return d, nil
}

func (uc *DriverUseCase) ListDrivers(ctx context.Context, status string, limit int, after string) ([]*entity.Driver, string, error) {
	return uc.repo.List(ctx, status, limit, after)
}

func (uc *DriverUseCase) UpdateDriverStatus(ctx context.Context, id uuid.UUID, status entity.DriverStatus) error {
	if err := uc.repo.UpdateStatus(ctx, id, status); err != nil {
		return fmt.Errorf("update driver status: %w", err)
	}
	return nil
}
