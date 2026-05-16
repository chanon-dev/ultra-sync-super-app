package port

import (
	"context"

	"github.com/google/uuid"
)

// WalletClient is the port the logistics service uses to charge a sender's
// wallet when a shipment is delivered (Saga step 2 of 2).
type WalletClient interface {
	ChargeForDelivery(ctx context.Context, shipmentID, userID uuid.UUID, amount, idempotencyKey string) error
}
