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
	wallets  port.WalletRepository
	txs      port.TransactionRepository
	notifier port.PushNotifier // optional; may be nil
}

func New(wallets port.WalletRepository, txs port.TransactionRepository) *WalletUseCase {
	return &WalletUseCase{wallets: wallets, txs: txs}
}

// WithNotifier attaches an optional push notifier.
func (uc *WalletUseCase) WithNotifier(n port.PushNotifier) *WalletUseCase {
	uc.notifier = n
	return uc
}

const (
	maxRetries          = 3
	errInvalidAmountFmt = "invalid amount: %s"
)

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
		return nil, fmt.Errorf(errInvalidAmountFmt, in.Amount)
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
	if uc.notifier != nil {
		_ = uc.notifier.NotifyTransactionComplete(ctx, in.UserID, string(entity.TxTopUp), tx.Amount)
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
		return nil, fmt.Errorf(errInvalidAmountFmt, in.Amount)
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

// TransferInput carries parameters for a P2P wallet transfer.
type TransferInput struct {
	FromUserID     uuid.UUID
	ToUserID       uuid.UUID
	Amount         string
	IdempotencyKey string
	Note           string
}

// Transfer moves funds from one user's wallet to another atomically using optimistic locking.
func (uc *WalletUseCase) Transfer(ctx context.Context, in TransferInput) (*entity.Transaction, error) {
	// Idempotency check.
	if existing, err := uc.txs.FindByIdempotencyKey(ctx, in.IdempotencyKey); err == nil {
		return existing, nil
	}

	amount, err := decimal.NewFromString(in.Amount)
	if err != nil || amount.LessThanOrEqual(decimal.Zero) {
		return nil, fmt.Errorf(errInvalidAmountFmt, in.Amount)
	}

	// Ensure both wallets exist.
	if _, err := uc.EnsureWallet(ctx, in.FromUserID); err != nil {
		return nil, fmt.Errorf("ensure sender wallet: %w", err)
	}
	if _, err := uc.EnsureWallet(ctx, in.ToUserID); err != nil {
		return nil, fmt.Errorf("ensure receiver wallet: %w", err)
	}

	// Debit sender.
	senderWallet, err := uc.debitWithRetry(ctx, in.FromUserID, in.Amount)
	if err != nil {
		return nil, fmt.Errorf("debit sender: %w", err)
	}

	// Credit receiver.
	if _, err = uc.creditWithRetry(ctx, in.ToUserID, in.Amount); err != nil {
		return nil, fmt.Errorf("credit receiver: %w", err)
	}

	// Record single transaction from sender's perspective (negative amount = debit).
	toUserRef := fmt.Sprintf("transfer-to:%s", in.ToUserID.String())
	senderBalance, _ := decimal.NewFromString(senderWallet.Balance)
	tx := &entity.Transaction{
		ID:             uuid.New(),
		WalletID:       in.FromUserID,
		Type:           entity.TxTransfer,
		Amount:         "-" + amount.StringFixed(4),
		BalanceAfter:   senderBalance.Sub(amount).StringFixed(4),
		ReferenceID:    &toUserRef,
		IdempotencyKey: in.IdempotencyKey,
		CreatedAt:      time.Now(),
	}
	if err := uc.txs.Create(ctx, tx); err != nil {
		return nil, fmt.Errorf("record transfer transaction: %w", err)
	}
	if uc.notifier != nil {
		_ = uc.notifier.NotifyTransactionComplete(ctx, in.FromUserID, string(entity.TxTransfer), tx.Amount)
	}
	return tx, nil
}

// PayoutInput carries parameters for a wallet payout to a bank account.
type PayoutInput struct {
	UserID         uuid.UUID
	Amount         string
	BankAccount    string // destination bank account reference
	IdempotencyKey string
}

// Payout debits the user's wallet and records a payout transaction.
func (uc *WalletUseCase) Payout(ctx context.Context, in PayoutInput) (*entity.Transaction, error) {
	// Idempotency check.
	if existing, err := uc.txs.FindByIdempotencyKey(ctx, in.IdempotencyKey); err == nil {
		return existing, nil
	}

	amount, err := decimal.NewFromString(in.Amount)
	if err != nil || amount.LessThanOrEqual(decimal.Zero) {
		return nil, fmt.Errorf(errInvalidAmountFmt, in.Amount)
	}

	wallet, err := uc.debitWithRetry(ctx, in.UserID, in.Amount)
	if err != nil {
		return nil, fmt.Errorf("debit for payout: %w", err)
	}

	bankRef := in.BankAccount
	walletBalance, _ := decimal.NewFromString(wallet.Balance)
	tx := &entity.Transaction{
		ID:             uuid.New(),
		WalletID:       in.UserID,
		Type:           entity.TxPayout,
		Amount:         "-" + amount.StringFixed(4),
		BalanceAfter:   walletBalance.Sub(amount).StringFixed(4),
		ReferenceID:    &bankRef,
		IdempotencyKey: in.IdempotencyKey,
		CreatedAt:      time.Now(),
	}
	if err := uc.txs.Create(ctx, tx); err != nil {
		return nil, fmt.Errorf("record payout transaction: %w", err)
	}
	if uc.notifier != nil {
		_ = uc.notifier.NotifyTransactionComplete(ctx, in.UserID, string(entity.TxPayout), tx.Amount)
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
