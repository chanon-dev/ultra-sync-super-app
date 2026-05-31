package domain

import (
	"context"

	"github.com/google/uuid"
)

type MessageRepository interface {
	Save(ctx context.Context, msg *ChatMessage) error
	GetByRoomID(ctx context.Context, roomID uuid.UUID, limit int, beforeID *uuid.UUID) ([]*ChatMessage, error)
}

type RoomRepository interface {
	Create(ctx context.Context, room *ChatRoom) error
	FindByID(ctx context.Context, id uuid.UUID) (*ChatRoom, error)
	List(ctx context.Context, userID uuid.UUID, limit int, afterID *uuid.UUID) ([]*ChatRoom, error)
	AddMember(ctx context.Context, roomID, userID uuid.UUID) error
	IsMember(ctx context.Context, roomID, userID uuid.UUID) (bool, error)
}

type FileStorage interface {
	Upload(ctx context.Context, filename string, data []byte, contentType string) (string, error)
}

type PubSubBroker interface {
	PublishMessage(ctx context.Context, roomID uuid.UUID, msg *ChatMessage) error
	SubscribeRoom(ctx context.Context, roomID uuid.UUID) (<-chan *ChatMessage, func(), error)
}

type EventPublisher interface {
	PublishChatEvent(ctx context.Context, msg *ChatMessage) error
}
