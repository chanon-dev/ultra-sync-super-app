package domain

import (
	"time"

	"github.com/google/uuid"
)

type ChatMessage struct {
	ID            uuid.UUID `json:"id"`
	RoomID        uuid.UUID `json:"room_id"`
	SenderID      uuid.UUID `json:"sender_id"`
	SenderRole    string    `json:"sender_role"`
	Content       string    `json:"content"`
	AttachmentURL *string   `json:"attachment_url,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
}
