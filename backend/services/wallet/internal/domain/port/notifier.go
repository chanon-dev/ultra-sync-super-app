package port

import (
	"context"

	"github.com/google/uuid"
)

// PushNotifier is the port for sending push notifications about wallet transactions.
type PushNotifier interface {
	NotifyTransactionComplete(ctx context.Context, userID uuid.UUID, txType string, amount string) error
}
