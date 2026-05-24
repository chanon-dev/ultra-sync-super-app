package kafkapub

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/IBM/sarama"
	"github.com/chanon/ultra-sync/services/chat/internal/domain"
	"go.uber.org/zap"
)

const (
	ChatTopic = "chat-messages"
	ChatGroup = "chat-db-writer"
)

type KafkaPublisher struct {
	producer sarama.SyncProducer
	log      *zap.Logger
}

func NewPublisher(brokers []string, log *zap.Logger) (*KafkaPublisher, error) {
	if len(brokers) == 0 {
		log.Warn("Kafka brokers list empty — chat events publisher running in NOOP fallback mode")
		return &KafkaPublisher{log: log}, nil
	}

	config := sarama.NewConfig()
	config.Producer.RequiredAcks = sarama.WaitForAll
	config.Producer.Retry.Max = 5
	config.Producer.Return.Successes = true
	// Use hash partitioning on key to guarantee messages in the same room land in the same partition
	config.Producer.Partitioner = sarama.NewHashPartitioner

	producer, err := sarama.NewSyncProducer(brokers, config)
	if err != nil {
		return nil, fmt.Errorf("create kafka sync producer: %w", err)
	}

	log.Info("Kafka chat event publisher initialized successfully", zap.Strings("brokers", brokers))
	return &KafkaPublisher{producer: producer, log: log}, nil
}

func (p *KafkaPublisher) PublishChatEvent(ctx context.Context, msg *domain.ChatMessage) error {
	if p.producer == nil {
		// NOOP fallback mode
		return fmt.Errorf("kafka publisher in NOOP mode")
	}

	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("marshal chat event: %w", err)
	}

	kafkaMsg := &sarama.ProducerMessage{
		Topic: ChatTopic,
		Key:   sarama.StringEncoder(msg.RoomID.String()),
		Value: sarama.ByteEncoder(data),
	}

	_, _, err = p.producer.SendMessage(kafkaMsg)
	if err != nil {
		p.log.Error("failed to publish chat event to Kafka", zap.Error(err))
		return fmt.Errorf("publish chat event to kafka: %w", err)
	}

	p.log.Debug("published chat message event to Kafka", zap.String("id", msg.ID.String()), zap.String("room", msg.RoomID.String()))
	return nil
}

func (p *KafkaPublisher) Close() error {
	if p.producer != nil {
		return p.producer.Close()
	}
	return nil
}

// =========================================================================
// Background Database Writer (Kafka Consumer)
// =========================================================================

type ChatConsumerGroupHandler struct {
	saveFn func(ctx context.Context, msg *domain.ChatMessage) error
	log    *zap.Logger
}

func NewConsumerHandler(saveFn func(ctx context.Context, msg *domain.ChatMessage) error, log *zap.Logger) *ChatConsumerGroupHandler {
	return &ChatConsumerGroupHandler{saveFn: saveFn, log: log}
}

func (ChatConsumerGroupHandler) Setup(_ sarama.ConsumerGroupSession) error   { return nil }
func (ChatConsumerGroupHandler) Cleanup(_ sarama.ConsumerGroupSession) error { return nil }

func (h ChatConsumerGroupHandler) ConsumeClaim(sess sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	for msg := range claim.Messages() {
		h.log.Debug("kafka consumer received chat message event", zap.ByteString("value", msg.Value))

		chatMsg := &domain.ChatMessage{}
		if err := json.Unmarshal(msg.Value, chatMsg); err != nil {
			h.log.Error("failed to unmarshal kafka chat event", zap.Error(err))
			sess.MarkMessage(msg, "")
			continue
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		if err := h.saveFn(ctx, chatMsg); err != nil {
			h.log.Error("background writer failed to save message to Postgres", zap.String("id", chatMsg.ID.String()), zap.Error(err))
			cancel()
			// Retry / block or skip depending on business rules; we mark message to keep consuming
			sess.MarkMessage(msg, "")
			continue
		}
		cancel()

		h.log.Info("background writer saved message asynchronously to Postgres", zap.String("id", chatMsg.ID.String()))
		sess.MarkMessage(msg, "")
	}
	return nil
}

// StartBackgroundWriter starts a background Kafka consumer group worker
func StartBackgroundWriter(ctx context.Context, brokers []string, saveFn func(ctx context.Context, msg *domain.ChatMessage) error, log *zap.Logger) {
	if len(brokers) == 0 {
		log.Warn("Kafka brokers list empty — background database writer worker is DISABLED")
		return
	}

	config := sarama.NewConfig()
	config.Consumer.Offsets.Initial = sarama.OffsetNewest
	config.Consumer.Return.Errors = true

	consumerGroup, err := sarama.NewConsumerGroup(brokers, ChatGroup, config)
	if err != nil {
		log.Error("failed to create kafka consumer group for chat background writer", zap.Error(err))
		return
	}

	handler := NewConsumerHandler(saveFn, log)

	go func() {
		defer consumerGroup.Close() //nolint:errcheck
		log.Info("Kafka background database writer worker starting consumer loop...")

		for {
			select {
			case <-ctx.Done():
				log.Info("Kafka background database writer worker context cancelled, stopping...")
				return
			default:
				if err := consumerGroup.Consume(ctx, []string{ChatTopic}, handler); err != nil {
					log.Error("kafka consumer group session error", zap.Error(err))
					time.Sleep(5 * time.Second) // wait before reconnecting
				}
			}
		}
	}()
}
