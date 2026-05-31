package entity

import (
	"time"

	"github.com/google/uuid"
)

type TransactionType string

const (
	TxTopUp    TransactionType = "topup"
	TxPayment  TransactionType = "payment"
	TxPayout   TransactionType = "payout"
	TxTransfer TransactionType = "transfer"
)

type Wallet struct {
	UserID    uuid.UUID
	Balance   string // DECIMAL(20,4) as string
	Currency  string
	Version   int // optimistic lock
	UpdatedAt time.Time
}

type Transaction struct {
	ID              uuid.UUID
	WalletID        uuid.UUID
	Type            TransactionType
	Amount          string // signed: negative for debit
	BalanceAfter    string
	ReferenceID     *string // order/shipment ID if applicable
	IdempotencyKey  string
	CreatedAt       time.Time
}
