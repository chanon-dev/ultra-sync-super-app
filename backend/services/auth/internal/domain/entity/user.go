package entity

import (
	"time"

	"github.com/google/uuid"
)

type Role string

const (
	RoleUser   Role = "user"
	RoleDriver Role = "driver"
	RoleAdmin  Role = "admin"
)

type UserStatus string

const (
	StatusPendingVerify UserStatus = "pending_verify"
	StatusActive        UserStatus = "active"
	StatusSuspended     UserStatus = "suspended"
)

type User struct {
	ID           uuid.UUID
	Email        string
	PasswordHash string
	Role         Role
	Status       UserStatus
	MFASecret    *string
	LastLoginAt  *time.Time
	CreatedAt    time.Time
	UpdatedAt    time.Time
}
