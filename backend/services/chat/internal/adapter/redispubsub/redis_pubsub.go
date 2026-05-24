package redispubsub

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/chanon/ultra-sync/services/chat/internal/domain"
)

type RedisPubSub struct {
	rdb *redis.Client
}

func New(rdb *redis.Client) *RedisPubSub {
	return &RedisPubSub{rdb: rdb}
}

func (r *RedisPubSub) PublishMessage(ctx context.Context, roomID uuid.UUID, msg *domain.ChatMessage) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("marshal message for redis: %w", err)
	}

	channel := getChannelName(roomID)
	if err := r.rdb.Publish(ctx, channel, data).Err(); err != nil {
		return fmt.Errorf("redis publish error: %w", err)
	}

	return nil
}

func (r *RedisPubSub) SubscribeRoom(ctx context.Context, roomID uuid.UUID) (<-chan *domain.ChatMessage, func(), error) {
	channel := getChannelName(roomID)
	pubsub := r.rdb.Subscribe(ctx, channel)

	// Verify subscription connection
	_, err := pubsub.Receive(ctx)
	if err != nil {
		_ = pubsub.Close()
		return nil, nil, fmt.Errorf("redis subscribe error: %w", err)
	}

	out := make(chan *domain.ChatMessage, 100)

	// Start subscriber worker in a separate goroutine
	go func() {
		defer close(out)
		ch := pubsub.Channel()

		for msg := range ch {
			chatMsg := &domain.ChatMessage{}
			if err := json.Unmarshal([]byte(msg.Payload), chatMsg); err != nil {
				// Log error or skip corrupt payloads
				continue
			}
			out <- chatMsg
		}
	}()

	cancel := func() {
		_ = pubsub.Unsubscribe(context.Background(), channel)
		_ = pubsub.Close()
	}

	return out, cancel, nil
}

func getChannelName(roomID uuid.UUID) string {
	return fmt.Sprintf("chat:room:%s", roomID.String())
}
