// Package events provides a no-op EventPublisher for development.
// Replace with a Kafka-backed implementation in production
// (e.g. using github.com/IBM/sarama or github.com/segmentio/kafka-go).
package events

import (
	"context"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/google/uuid"
)

type NoopPublisher struct{}

func NewNoop() *NoopPublisher { return &NoopPublisher{} }

func (n *NoopPublisher) PublishShipmentCreated(_ context.Context, _ *entity.Shipment) error {
	return nil
}

func (n *NoopPublisher) PublishStatusUpdated(_ context.Context, _ uuid.UUID, _ entity.ShipmentStatus) error {
	return nil
}
