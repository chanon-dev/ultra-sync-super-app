package notifier

import (
	"context"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/logistics/internal/domain/port"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

type NoopNotifier struct {
	log *zap.Logger
}

func New(log *zap.Logger) port.PushNotifier {
	return &NoopNotifier{log: log}
}

func (n *NoopNotifier) NotifyShipmentStatusChange(_ context.Context, userID, shipmentID uuid.UUID, status entity.ShipmentStatus) error {
	n.log.Info("push notification (noop)",
		zap.String("event", "status_change"),
		zap.String("status", string(status)),
		zap.String("user_id", userID.String()),
		zap.String("shipment_id", shipmentID.String()),
	)
	return nil
}

func (n *NoopNotifier) NotifyDriverAssigned(_ context.Context, userID, driverID uuid.UUID) error {
	n.log.Info("push notification (noop)",
		zap.String("event", "driver_assigned"),
		zap.String("user_id", userID.String()),
		zap.String("driver_id", driverID.String()),
	)
	return nil
}
