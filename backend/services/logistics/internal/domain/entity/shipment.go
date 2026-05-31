package entity

import (
	"time"

	"github.com/google/uuid"
)

type ShipmentStatus string

const (
	StatusPending   ShipmentStatus = "pending"
	StatusAssigned  ShipmentStatus = "assigned"
	StatusPickedUp  ShipmentStatus = "picked_up"
	StatusShipping  ShipmentStatus = "shipping"
	StatusDelivered ShipmentStatus = "delivered"
	StatusCancelled ShipmentStatus = "cancelled"
)

type GeoPoint struct {
	Latitude  float64
	Longitude float64
}

type Shipment struct {
	ID             uuid.UUID
	OrderNo        string
	SenderID       uuid.UUID
	DriverID       *uuid.UUID
	Status         ShipmentStatus
	PickupGeo      GeoPoint
	DropoffGeo     GeoPoint
	Price          string // DECIMAL(20,4) as string — use shopspring/decimal for arithmetic
	IdempotencyKey string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type ShipmentLog struct {
	ID         int64
	ShipmentID uuid.UUID
	Status     ShipmentStatus
	CurrentGeo GeoPoint
	SpeedKmH   float64
	CreatedAt  time.Time
}
