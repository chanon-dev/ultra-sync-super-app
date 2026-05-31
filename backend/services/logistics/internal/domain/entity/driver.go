package entity

import (
	"time"

	"github.com/google/uuid"
)

type DriverStatus string

const (
	DriverStatusActive   DriverStatus = "active"
	DriverStatusInactive DriverStatus = "inactive"
)

type Driver struct {
	ID           uuid.UUID
	UserID       uuid.UUID
	Name         string
	PhoneNumber  string
	VehicleType  string // "motorcycle", "car", "truck"
	LicensePlate string
	Status       DriverStatus
	Rating       float64 // 0.0–5.0
	CreatedAt    time.Time
	UpdatedAt    time.Time
}
