package domain

import (
	"context"

	"github.com/google/uuid"
)

type MessageRepository interface {
	Save(ctx context.Context, msg *ChatMessage) error
	GetByRoomID(ctx context.Context, roomID uuid.UUID, limit int, beforeID *uuid.UUID) ([]*ChatMessage, error)
}

type PubSubBroker interface {
	PublishMessage(ctx context.Context, roomID uuid.UUID, msg *ChatMessage) error
	SubscribeRoom(ctx context.Context, roomID uuid.UUID) (<-chan *ChatMessage, func(), error)
}

type EventPublisher interface {
	PublishChatEvent(ctx context.Context, msg *ChatMessage) error
}
