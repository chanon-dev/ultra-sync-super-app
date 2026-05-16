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

func wrapFindWallet(err error) error { return fmt.Errorf("find wallet: %w", err) }

type TopUpInput struct {
	UserID         uuid.UUID
	Amount         string
	IdempotencyKey string
}

func (uc *WalletUseCase) TopUp(ctx context.Context, in TopUpInput) (*entity.Transaction, error) {
	if existing, err := uc.txs.FindByIdempotencyKey(ctx, in.IdempotencyKey); err == nil {
		return existing, nil
	}

	amount, err := decimal.NewFromString(in.Amount)
	if err != nil || amount.LessThanOrEqual(decimal.Zero) {
		return nil, fmt.Errorf("invalid amount: %s", in.Amount)
	}

	wallet, err := uc.creditWithRetry(ctx, in.UserID, in.Amount)
	if err != nil {
		return nil, err
	}

	currentBalance, _ := decimal.NewFromString(wallet.Balance)
	tx := &entity.Transaction{
		ID:             uuid.New(),
		WalletID:       in.UserID,
		Type:           entity.TxTopUp,
		Amount:         amount.StringFixed(4),
		BalanceAfter:   currentBalance.Add(amount).StringFixed(4),
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
		return nil, wrapFindWallet(err)
	}

	balance, _ := decimal.NewFromString(wallet.Balance)
	if balance.LessThan(amount) {
		return nil, fmt.Errorf("insufficient balance")
	}

	if wallet, err = uc.debitWithRetry(ctx, in.FromUserID, in.Amount); err != nil {
		return nil, err
	}

	shipmentRef := in.ShipmentID.String()
	balance, _ = decimal.NewFromString(wallet.Balance)
	tx := &entity.Transaction{
		ID:             uuid.New(),
		WalletID:       in.FromUserID,
		Type:           entity.TxPayment,
		Amount:         "-" + amount.StringFixed(4),
		BalanceAfter:   balance.Sub(amount).StringFixed(4),
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

// EnsureWallet returns the wallet for userID, creating a zero-balance one on first access.
func (uc *WalletUseCase) EnsureWallet(ctx context.Context, userID uuid.UUID) (*entity.Wallet, error) {
	w, err := uc.wallets.FindByUserID(ctx, userID)
	if err == nil {
		return w, nil
	}
	w = &entity.Wallet{UserID: userID, Balance: "0.0000", Currency: "THB", UpdatedAt: time.Now()}
	if err := uc.wallets.Create(ctx, w); err != nil {
		return nil, fmt.Errorf("provision wallet: %w", err)
	}
	return w, nil
}

// creditWithRetry credits amount with optimistic-lock retries. Returns the wallet state used for the last attempt.
func (uc *WalletUseCase) creditWithRetry(ctx context.Context, userID uuid.UUID, amount string) (*entity.Wallet, error) {
	w, err := uc.wallets.FindByUserID(ctx, userID)
	if err != nil {
		return nil, wrapFindWallet(err)
	}
	for attempt := 0; attempt < maxRetries; attempt++ {
		if err = uc.wallets.CreditWithLock(ctx, userID, amount, w.Version); err == nil {
			return w, nil
		}
		if attempt < maxRetries-1 {
			if w, err = uc.wallets.FindByUserID(ctx, userID); err != nil {
				return nil, fmt.Errorf("reload wallet: %w", err)
			}
		}
	}
	return nil, fmt.Errorf("credit wallet after %d retries: %w", maxRetries, err)
}

// debitWithRetry debits amount with optimistic-lock retries. Returns the wallet state used for the last attempt.
func (uc *WalletUseCase) debitWithRetry(ctx context.Context, userID uuid.UUID, amount string) (*entity.Wallet, error) {
	w, err := uc.wallets.FindByUserID(ctx, userID)
	if err != nil {
		return nil, wrapFindWallet(err)
	}
	for attempt := 0; attempt < maxRetries; attempt++ {
		if err = uc.wallets.DebitWithLock(ctx, userID, amount, w.Version); err == nil {
			return w, nil
		}
		if attempt < maxRetries-1 {
			if w, err = uc.wallets.FindByUserID(ctx, userID); err != nil {
				return nil, fmt.Errorf("reload wallet: %w", err)
			}
		}
	}
	return nil, fmt.Errorf("debit wallet after %d retries: %w", maxRetries, err)
}
