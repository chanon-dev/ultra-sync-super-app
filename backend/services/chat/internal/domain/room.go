package domain

import (
	"time"

	"github.com/google/uuid"
)

type ChatRoom struct {
	ID        uuid.UUID `json:"id"`
	Name      string    `json:"name"`
	CreatedBy uuid.UUID `json:"created_by"`
	CreatedAt time.Time `json:"created_at"`
}
