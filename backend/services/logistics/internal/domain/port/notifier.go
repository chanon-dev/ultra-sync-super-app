package port

import (
	"context"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/google/uuid"
)

type PushNotifier interface {
	NotifyShipmentStatusChange(ctx context.Context, userID, shipmentID uuid.UUID, status entity.ShipmentStatus) error
	NotifyDriverAssigned(ctx context.Context, userID, driverID uuid.UUID) error
}
