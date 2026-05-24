package usecase

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/chanon/ultra-sync/services/chat/internal/domain"
)

type chatUseCase struct {
	repo      domain.MessageRepository
	broker    domain.PubSubBroker
	publisher domain.EventPublisher
}

func New(repo domain.MessageRepository, broker domain.PubSubBroker, publisher domain.EventPublisher) *chatUseCase {
	return &chatUseCase{
		repo:      repo,
		broker:    broker,
		publisher: publisher,
	}
}

func (uc *chatUseCase) LoadHistory(ctx context.Context, roomID uuid.UUID, limit int, beforeID *uuid.UUID) ([]*domain.ChatMessage, error) {
	if roomID == uuid.Nil {
		return nil, errors.New("invalid room id")
	}
	if limit <= 0 {
		limit = 20
	}
	return uc.repo.GetByRoomID(ctx, roomID, limit, beforeID)
}

func (uc *chatUseCase) SendMessage(ctx context.Context, senderID uuid.UUID, senderRole string, roomID uuid.UUID, content string) (*domain.ChatMessage, error) {
	if roomID == uuid.Nil {
		return nil, errors.New("invalid room id")
	}
	if senderID == uuid.Nil {
		return nil, errors.New("invalid sender id")
	}
	if content == "" {
		return nil, errors.New("message content cannot be empty")
	}

	msg := &domain.ChatMessage{
		ID:         uuid.New(),
		RoomID:     roomID,
		SenderID:   senderID,
		SenderRole: senderRole,
		Content:    content,
		CreatedAt:  time.Now(),
	}

	// 1. Instantly publish to Redis Pub/Sub for real-time WebSocket delivery
	if err := uc.broker.PublishMessage(ctx, roomID, msg); err != nil {
		return nil, err
	}

	// 2. Publish to Kafka for asynchronous durable logging and auditing
	if err := uc.publisher.PublishChatEvent(ctx, msg); err != nil {
		// Fallback to write directly to DB if Kafka is disabled/erroring (dev mode)
		_ = uc.repo.Save(ctx, msg)
	}

	return msg, nil
}

func (uc *chatUseCase) SubscribeRoom(ctx context.Context, roomID uuid.UUID) (<-chan *domain.ChatMessage, func(), error) {
	if roomID == uuid.Nil {
		return nil, nil, errors.New("invalid room id")
	}
	return uc.broker.SubscribeRoom(ctx, roomID)
}

// SaveMessage is called by the background Kafka consumer worker
func (uc *chatUseCase) SaveMessage(ctx context.Context, msg *domain.ChatMessage) error {
	return uc.repo.Save(ctx, msg)
}
