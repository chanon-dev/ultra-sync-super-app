package usecase

import (
	"context"
	"fmt"
	"time"

	"github.com/chanon/ultra-sync/services/wallet/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/wallet/internal/domain/port"
	"github.com/google/uuid"
	"github.com/shopspring/decimal"
)

type WalletUseCase struct {
	wallets port.WalletRepository
	txs     port.TransactionRepository
}

func New(wallets port.WalletRepository, txs port.TransactionRepository) *WalletUseCase {
	return &WalletUseCase{wallets: wallets, txs: txs}
}

const maxRetries = 3

type TopUpInput struct {
	UserID         uuid.UUID
	Amount         string
	IdempotencyKey string
}

func (uc *WalletUseCase) TopUp(ctx context.Context, in TopUpInput) (*entity.Transaction, error) {
	// Idempotency check
	if existing, err := uc.txs.FindByIdempotencyKey(ctx, in.IdempotencyKey); err == nil {
		return existing, nil
	}

	amount, err := decimal.NewFromString(in.Amount)
	if err != nil || amount.LessThanOrEqual(decimal.Zero) {
		return nil, fmt.Errorf("invalid amount: %s", in.Amount)
	}

	wallet, err := uc.wallets.FindByUserID(ctx, in.UserID)
	if err != nil {
		return nil, fmt.Errorf("find wallet: %w", err)
	}

	for attempt := 0; attempt < maxRetries; attempt++ {
		if err := uc.wallets.CreditWithLock(ctx, in.UserID, in.Amount, wallet.Version); err != nil {
			if attempt < maxRetries-1 {
				wallet, err = uc.wallets.FindByUserID(ctx, in.UserID)
				if err != nil {
					return nil, fmt.Errorf("reload wallet: %w", err)
				}
				continue
			}
			return nil, fmt.Errorf("credit wallet after %d retries: %w", maxRetries, err)
		}
		break
	}

	currentBalance, _ := decimal.NewFromString(wallet.Balance)
	balanceAfter := currentBalance.Add(amount).StringFixed(4)

	tx := &entity.Transaction{
		ID:             uuid.New(),
		WalletID:       in.UserID,
		Type:           entity.TxTopUp,
		Amount:         amount.StringFixed(4),
		BalanceAfter:   balanceAfter,
		IdempotencyKey: in.IdempotencyKey,
		CreatedAt:      time.Now(),
	}
	if err := uc.txs.Create(ctx, tx); err != nil {
		return nil, fmt.Errorf("record transaction: %w", err)
	}

	return tx, nil
}

type PayInput struct {
	FromUserID     uuid.UUID
	ShipmentID     uuid.UUID
	Amount         string
	IdempotencyKey string
}

func (uc *WalletUseCase) Pay(ctx context.Context, in PayInput) (*entity.Transaction, error) {
	if existing, err := uc.txs.FindByIdempotencyKey(ctx, in.IdempotencyKey); err == nil {
		return existing, nil
	}

	amount, err := decimal.NewFromString(in.Amount)
	if err != nil || amount.LessThanOrEqual(decimal.Zero) {
		return nil, fmt.Errorf("invalid amount: %s", in.Amount)
	}

	wallet, err := uc.wallets.FindByUserID(ctx, in.FromUserID)
	if err != nil {
		return nil, fmt.Errorf("find wallet: %w", err)
	}

	balance, _ := decimal.NewFromString(wallet.Balance)
	if balance.LessThan(amount) {
		return nil, fmt.Errorf("insufficient balance")
	}

	for attempt := 0; attempt < maxRetries; attempt++ {
		if err := uc.wallets.DebitWithLock(ctx, in.FromUserID, in.Amount, wallet.Version); err != nil {
			if attempt < maxRetries-1 {
				wallet, err = uc.wallets.FindByUserID(ctx, in.FromUserID)
				if err != nil {
					return nil, fmt.Errorf("reload wallet: %w", err)
				}
				continue
			}
			return nil, fmt.Errorf("debit wallet after %d retries: %w", maxRetries, err)
		}
		break
	}

	shipmentRef := in.ShipmentID.String()
	balanceAfter := balance.Sub(amount).StringFixed(4)

	tx := &entity.Transaction{
		ID:             uuid.New(),
		WalletID:       in.FromUserID,
		Type:           entity.TxPayment,
		Amount:         "-" + amount.StringFixed(4),
		BalanceAfter:   balanceAfter,
		ReferenceID:    &shipmentRef,
		IdempotencyKey: in.IdempotencyKey,
		CreatedAt:      time.Now(),
	}
	if err := uc.txs.Create(ctx, tx); err != nil {
		return nil, fmt.Errorf("record transaction: %w", err)
	}

	return tx, nil
}

func (uc *WalletUseCase) GetBalance(ctx context.Context, userID uuid.UUID) (*entity.Wallet, error) {
	return uc.wallets.FindByUserID(ctx, userID)
}

func (uc *WalletUseCase) ListTransactions(ctx context.Context, q port.ListQuery) ([]*entity.Transaction, string, error) {
	return uc.txs.List(ctx, q)
}
