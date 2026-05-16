package events

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/IBM/sarama"
	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/google/uuid"
)

const shipmentEventsTopic = "shipment-events"

// KafkaPublisher is a production EventPublisher backed by Apache Kafka.
// Use NewKafka(brokers) and wire via KAFKA_BROKERS env var in main.go.
type KafkaPublisher struct {
	producer sarama.SyncProducer
}

func NewKafka(brokers []string) (*KafkaPublisher, error) {
	cfg := sarama.NewConfig()
	cfg.Producer.Return.Successes = true
	cfg.Producer.RequiredAcks = sarama.WaitForAll
	cfg.Producer.Retry.Max = 3

	producer, err := sarama.NewSyncProducer(brokers, cfg)
	if err != nil {
		return nil, fmt.Errorf("create kafka producer: %w", err)
	}
	return &KafkaPublisher{producer: producer}, nil
}

func (k *KafkaPublisher) Close() error {
	return k.producer.Close()
}

func (k *KafkaPublisher) PublishShipmentCreated(_ context.Context, s *entity.Shipment) error {
	payload, err := json.Marshal(map[string]any{
		"event":       "shipment.created",
		"shipment_id": s.ID,
		"order_no":    s.OrderNo,
		"sender_id":   s.SenderID,
		"status":      s.Status,
	})
	if err != nil {
		return fmt.Errorf("marshal shipment.created: %w", err)
	}
	return k.send(s.ID.String(), payload)
}

func (k *KafkaPublisher) PublishStatusUpdated(_ context.Context, shipmentID uuid.UUID, status entity.ShipmentStatus) error {
	payload, err := json.Marshal(map[string]any{
		"event":       "shipment.status_updated",
		"shipment_id": shipmentID,
		"status":      status,
	})
	if err != nil {
		return fmt.Errorf("marshal status_updated: %w", err)
	}
	return k.send(shipmentID.String(), payload)
}

func (k *KafkaPublisher) send(key string, payload []byte) error {
	_, _, err := k.producer.SendMessage(&sarama.ProducerMessage{
		Topic: shipmentEventsTopic,
		Key:   sarama.StringEncoder(key),
		Value: sarama.ByteEncoder(payload),
	})
	if err != nil {
		return fmt.Errorf("send kafka message: %w", err)
	}
	return nil
}
