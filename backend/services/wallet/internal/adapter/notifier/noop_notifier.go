package notifier

import (
	"context"

	"github.com/chanon/ultra-sync/services/wallet/internal/domain/port"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

type NoopNotifier struct{ log *zap.Logger }

// New returns a noop PushNotifier that logs instead of sending real push notifications.
func New(log *zap.Logger) port.PushNotifier { return &NoopNotifier{log: log} }

func (n *NoopNotifier) NotifyTransactionComplete(ctx context.Context, userID uuid.UUID, txType string, amount string) error {
	n.log.Info("push notification (noop)",
		zap.String("event", "transaction_complete"),
		zap.String("user_id", userID.String()),
		zap.String("tx_type", txType),
		zap.String("amount", amount),
	)
	return nil
}
