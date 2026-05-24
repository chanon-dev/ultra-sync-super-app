package usecase

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/chanon/ultra-sync/services/chat/internal/domain"
)

// =========================================================================
// Mocks
// =========================================================================

type mockRepo struct {
	messages []*domain.ChatMessage
	saveErr  error
}

func (m *mockRepo) Save(ctx context.Context, msg *domain.ChatMessage) error {
	if m.saveErr != nil {
		return m.saveErr
	}
	m.messages = append(m.messages, msg)
	return nil
}

func (m *mockRepo) GetByRoomID(ctx context.Context, roomID uuid.UUID, limit int, beforeID *uuid.UUID) ([]*domain.ChatMessage, error) {
	return m.messages, nil
}

type mockBroker struct {
	published []*domain.ChatMessage
	pubErr    error
}

func (m *mockBroker) PublishMessage(ctx context.Context, roomID uuid.UUID, msg *domain.ChatMessage) error {
	if m.pubErr != nil {
		return m.pubErr
	}
	m.published = append(m.published, msg)
	return nil
}

func (m *mockBroker) SubscribeRoom(ctx context.Context, roomID uuid.UUID) (<-chan *domain.ChatMessage, func(), error) {
	ch := make(chan *domain.ChatMessage, 1)
	return ch, func() {}, nil
}

type mockPublisher struct {
	published []*domain.ChatMessage
	pubErr    error
}

func (m *mockPublisher) PublishChatEvent(ctx context.Context, msg *domain.ChatMessage) error {
	if m.pubErr != nil {
		return m.pubErr
	}
	m.published = append(m.published, msg)
	return nil
}

// =========================================================================
// Tests
// =========================================================================

func TestSendMessage_Success(t *testing.T) {
	repo := &mockRepo{}
	broker := &mockBroker{}
	pub := &mockPublisher{}

	uc := New(repo, broker, pub)

	senderID := uuid.New()
	roomID := uuid.New()
	content := "Hello, this is a test message!"

	msg, err := uc.SendMessage(context.Background(), senderID, "user", roomID, content)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if msg.Content != content {
		t.Errorf("expected content %q, got %q", content, msg.Content)
	}
	if msg.SenderID != senderID {
		t.Errorf("expected sender id %s, got %s", senderID, msg.SenderID)
	}
	if msg.RoomID != roomID {
		t.Errorf("expected room id %s, got %s", roomID, msg.RoomID)
	}
	if msg.SenderRole != "user" {
		t.Errorf("expected sender role %q, got %q", "user", msg.SenderRole)
	}

	// Verify it was published to Redis Broker
	if len(broker.published) != 1 {
		t.Errorf("expected 1 published broker message, got %d", len(broker.published))
	}

	// Verify it was published to Kafka EventPublisher
	if len(pub.published) != 1 {
		t.Errorf("expected 1 published kafka event, got %d", len(pub.published))
	}
}

func TestSendMessage_ValidationError(t *testing.T) {
	repo := &mockRepo{}
	broker := &mockBroker{}
	pub := &mockPublisher{}

	uc := New(repo, broker, pub)

	// Test missing room id
	_, err := uc.SendMessage(context.Background(), uuid.New(), "user", uuid.Nil, "content")
	if err == nil {
		t.Error("expected error for missing room id, got nil")
	}

	// Test missing sender id
	_, err = uc.SendMessage(context.Background(), uuid.Nil, "user", uuid.New(), "content")
	if err == nil {
		t.Error("expected error for missing sender id, got nil")
	}

	// Test empty content
	_, err = uc.SendMessage(context.Background(), uuid.New(), "user", uuid.New(), "")
	if err == nil {
		t.Error("expected error for empty content, got nil")
	}
}

func TestSendMessage_KafkaFallback(t *testing.T) {
	repo := &mockRepo{}
	broker := &mockBroker{}
	// Make Kafka publish fail to trigger direct DB write fallback
	pub := &mockPublisher{pubErr: errors.New("kafka connection timed out")}

	uc := New(repo, broker, pub)

	senderID := uuid.New()
	roomID := uuid.New()
	content := "Fallback messaging test"

	_, err := uc.SendMessage(context.Background(), senderID, "driver", roomID, content)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Verify that it fell back and saved directly to the database repo
	if len(repo.messages) != 1 {
		t.Errorf("expected message to be saved directly to DB, got %d messages", len(repo.messages))
	}
}

func TestLoadHistory(t *testing.T) {
	repo := &mockRepo{
		messages: []*domain.ChatMessage{
			{ID: uuid.New(), Content: "msg 1", CreatedAt: time.Now()},
			{ID: uuid.New(), Content: "msg 2", CreatedAt: time.Now()},
		},
	}
	broker := &mockBroker{}
	pub := &mockPublisher{}

	uc := New(repo, broker, pub)

	history, err := uc.LoadHistory(context.Background(), uuid.New(), 10, nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(history) != 2 {
		t.Errorf("expected 2 history messages, got %d", len(history))
	}
}
