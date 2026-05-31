package usecase

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/chanon/ultra-sync/services/chat/internal/domain"
	"github.com/google/uuid"
)

type chatUseCase struct {
	repo      domain.MessageRepository
	broker    domain.PubSubBroker
	publisher domain.EventPublisher
	rooms     domain.RoomRepository
	storage   domain.FileStorage
}

func New(
	repo domain.MessageRepository,
	broker domain.PubSubBroker,
	publisher domain.EventPublisher,
	rooms domain.RoomRepository,
	storage domain.FileStorage,
) *chatUseCase {
	return &chatUseCase{
		repo:      repo,
		broker:    broker,
		publisher: publisher,
		rooms:     rooms,
		storage:   storage,
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

	if err := uc.broker.PublishMessage(ctx, roomID, msg); err != nil {
		return nil, err
	}

	if err := uc.publisher.PublishChatEvent(ctx, msg); err != nil {
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

// SaveMessage is called by the background Kafka consumer worker.
func (uc *chatUseCase) SaveMessage(ctx context.Context, msg *domain.ChatMessage) error {
	return uc.repo.Save(ctx, msg)
}

// --- Room Management ---

func (uc *chatUseCase) CreateRoom(ctx context.Context, name string, createdBy uuid.UUID) (*domain.ChatRoom, error) {
	if name == "" {
		return nil, errors.New("room name cannot be empty")
	}
	if createdBy == uuid.Nil {
		return nil, errors.New("invalid creator id")
	}
	room := &domain.ChatRoom{
		ID:        uuid.New(),
		Name:      name,
		CreatedBy: createdBy,
		CreatedAt: time.Now(),
	}
	if err := uc.rooms.Create(ctx, room); err != nil {
		return nil, fmt.Errorf("create room: %w", err)
	}
	return room, nil
}

func (uc *chatUseCase) GetRoom(ctx context.Context, id uuid.UUID) (*domain.ChatRoom, error) {
	if id == uuid.Nil {
		return nil, errors.New("invalid room id")
	}
	room, err := uc.rooms.FindByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("find room: %w", err)
	}
	return room, nil
}

func (uc *chatUseCase) ListRooms(ctx context.Context, userID uuid.UUID, limit int, afterID *uuid.UUID) ([]*domain.ChatRoom, error) {
	if userID == uuid.Nil {
		return nil, errors.New("invalid user id")
	}
	if limit <= 0 {
		limit = 20
	}
	return uc.rooms.List(ctx, userID, limit, afterID)
}

func (uc *chatUseCase) JoinRoom(ctx context.Context, roomID, userID uuid.UUID) error {
	if _, err := uc.rooms.FindByID(ctx, roomID); err != nil {
		return fmt.Errorf("room not found: %w", err)
	}
	return uc.rooms.AddMember(ctx, roomID, userID)
}

// --- File Upload ---

func (uc *chatUseCase) UploadAttachment(ctx context.Context, filename string, data []byte, contentType string) (string, error) {
	if uc.storage == nil {
		return "", errors.New("file storage not configured")
	}
	if len(data) == 0 {
		return "", errors.New("file is empty")
	}
	url, err := uc.storage.Upload(ctx, filename, data, contentType)
	if err != nil {
		return "", fmt.Errorf("upload attachment: %w", err)
	}
	return url, nil
}
