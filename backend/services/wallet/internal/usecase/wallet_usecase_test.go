package usecase_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/chanon/ultra-sync/services/wallet/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/wallet/internal/domain/port"
	"github.com/chanon/ultra-sync/services/wallet/internal/usecase"
	"github.com/google/uuid"
)

// ── Mocks ─────────────────────────────────────────────────────────────────────

var errNotFound = errors.New("not found")

type stubWalletRepo struct {
	findByUserIDFn   func(ctx context.Context, userID uuid.UUID) (*entity.Wallet, error)
	creditWithLockFn func(ctx context.Context, userID uuid.UUID, amount string, version int) error
	debitWithLockFn  func(ctx context.Context, userID uuid.UUID, amount string, version int) error
	createFn         func(ctx context.Context, w *entity.Wallet) error
}

func (s *stubWalletRepo) FindByUserID(ctx context.Context, userID uuid.UUID) (*entity.Wallet, error) {
	return s.findByUserIDFn(ctx, userID)
}
func (s *stubWalletRepo) CreditWithLock(ctx context.Context, userID uuid.UUID, amount string, version int) error {
	return s.creditWithLockFn(ctx, userID, amount, version)
}
func (s *stubWalletRepo) DebitWithLock(ctx context.Context, userID uuid.UUID, amount string, version int) error {
	return s.debitWithLockFn(ctx, userID, amount, version)
}
func (s *stubWalletRepo) Create(ctx context.Context, w *entity.Wallet) error {
	return s.createFn(ctx, w)
}

type stubTxRepo struct {
	findByIdempotencyKeyFn func(ctx context.Context, key string) (*entity.Transaction, error)
	createFn               func(ctx context.Context, tx *entity.Transaction) error
	listFn                 func(ctx context.Context, q port.ListQuery) ([]*entity.Transaction, string, error)
}

func (s *stubTxRepo) FindByIdempotencyKey(ctx context.Context, key string) (*entity.Transaction, error) {
	return s.findByIdempotencyKeyFn(ctx, key)
}
func (s *stubTxRepo) Create(ctx context.Context, tx *entity.Transaction) error {
	return s.createFn(ctx, tx)
}
func (s *stubTxRepo) List(ctx context.Context, q port.ListQuery) ([]*entity.Transaction, string, error) {
	return s.listFn(ctx, q)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

func makeWallet(userID uuid.UUID, balance string, version int) *entity.Wallet {
	return &entity.Wallet{
		UserID:    userID,
		Balance:   balance,
		Currency:  "THB",
		Version:   version,
		UpdatedAt: time.Now(),
	}
}

func noopTxCreate(_ context.Context, _ *entity.Transaction) error { return nil }

// ── TopUp ─────────────────────────────────────────────────────────────────────

func TestTopUp_Idempotent(t *testing.T) {
	existing := &entity.Transaction{ID: uuid.New(), IdempotencyKey: "key-1"}
	uc := usecase.New(
		&stubWalletRepo{},
		&stubTxRepo{
			findByIdempotencyKeyFn: func(_ context.Context, _ string) (*entity.Transaction, error) {
				return existing, nil
			},
		},
	)
	got, err := uc.TopUp(context.Background(), usecase.TopUpInput{
		UserID:         uuid.New(),
		Amount:         "100.0000",
		IdempotencyKey: "key-1",
	})
	if err != nil {
		t.Fatalf("expected nil error, got %v", err)
	}
	if got.ID != existing.ID {
		t.Fatal("expected existing transaction to be returned unchanged")
	}
}

func TestTopUp_InvalidAmount(t *testing.T) {
	txRepo := &stubTxRepo{
		findByIdempotencyKeyFn: func(_ context.Context, _ string) (*entity.Transaction, error) {
			return nil, errNotFound
		},
	}
	uc := usecase.New(&stubWalletRepo{}, txRepo)

	for _, amt := range []string{"0", "-10", "abc", "0.0000"} {
		_, err := uc.TopUp(context.Background(), usecase.TopUpInput{
			UserID: uuid.New(), Amount: amt, IdempotencyKey: "key-x",
		})
		if err == nil {
			t.Errorf("expected error for invalid amount %q", amt)
		}
	}
}

func TestTopUp_Success(t *testing.T) {
	userID := uuid.New()
	w := makeWallet(userID, "0.0000", 0)

	uc := usecase.New(
		&stubWalletRepo{
			findByUserIDFn:   func(_ context.Context, _ uuid.UUID) (*entity.Wallet, error) { return w, nil },
			creditWithLockFn: func(_ context.Context, _ uuid.UUID, _ string, _ int) error { return nil },
		},
		&stubTxRepo{
			findByIdempotencyKeyFn: func(_ context.Context, _ string) (*entity.Transaction, error) { return nil, errNotFound },
			createFn:               noopTxCreate,
		},
	)

	tx, err := uc.TopUp(context.Background(), usecase.TopUpInput{
		UserID: userID, Amount: "100.0000", IdempotencyKey: "uniq",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tx.Type != entity.TxTopUp {
		t.Errorf("expected TxTopUp, got %s", tx.Type)
	}
	if tx.Amount != "100.0000" {
		t.Errorf("expected amount 100.0000, got %s", tx.Amount)
	}
}

func TestTopUp_OptimisticLockRetrySuccess(t *testing.T) {
	userID := uuid.New()
	calls := 0
	w0 := makeWallet(userID, "0.0000", 0)
	w1 := makeWallet(userID, "0.0000", 1)

	uc := usecase.New(
		&stubWalletRepo{
			findByUserIDFn: func(_ context.Context, _ uuid.UUID) (*entity.Wallet, error) {
				calls++
				if calls == 1 {
					return w0, nil
				}
				return w1, nil
			},
			creditWithLockFn: func(_ context.Context, _ uuid.UUID, _ string, version int) error {
				if version == 0 {
					return errors.New("version conflict")
				}
				return nil
			},
		},
		&stubTxRepo{
			findByIdempotencyKeyFn: func(_ context.Context, _ string) (*entity.Transaction, error) { return nil, errNotFound },
			createFn:               noopTxCreate,
		},
	)

	_, err := uc.TopUp(context.Background(), usecase.TopUpInput{
		UserID: userID, Amount: "50.0000", IdempotencyKey: "retry-key",
	})
	if err != nil {
		t.Fatalf("expected success after retry, got: %v", err)
	}
}

func TestTopUp_AllRetriesExhausted(t *testing.T) {
	userID := uuid.New()
	w := makeWallet(userID, "0.0000", 0)

	uc := usecase.New(
		&stubWalletRepo{
			findByUserIDFn:   func(_ context.Context, _ uuid.UUID) (*entity.Wallet, error) { return w, nil },
			creditWithLockFn: func(_ context.Context, _ uuid.UUID, _ string, _ int) error { return errors.New("conflict") },
		},
		&stubTxRepo{
			findByIdempotencyKeyFn: func(_ context.Context, _ string) (*entity.Transaction, error) { return nil, errNotFound },
		},
	)

	_, err := uc.TopUp(context.Background(), usecase.TopUpInput{
		UserID: userID, Amount: "50.0000", IdempotencyKey: "exhaust",
	})
	if err == nil {
		t.Fatal("expected error when all retries exhausted")
	}
}

// ── Pay ───────────────────────────────────────────────────────────────────────

func TestPay_Idempotent(t *testing.T) {
	existing := &entity.Transaction{ID: uuid.New(), IdempotencyKey: "pay-key"}
	uc := usecase.New(
		&stubWalletRepo{},
		&stubTxRepo{
			findByIdempotencyKeyFn: func(_ context.Context, _ string) (*entity.Transaction, error) { return existing, nil },
		},
	)
	got, err := uc.Pay(context.Background(), usecase.PayInput{
		FromUserID: uuid.New(), ShipmentID: uuid.New(), Amount: "100.0000", IdempotencyKey: "pay-key",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.ID != existing.ID {
		t.Fatal("expected existing transaction")
	}
}

func TestPay_InsufficientBalance(t *testing.T) {
	userID := uuid.New()
	w := makeWallet(userID, "50.0000", 0)

	uc := usecase.New(
		&stubWalletRepo{
			findByUserIDFn: func(_ context.Context, _ uuid.UUID) (*entity.Wallet, error) { return w, nil },
		},
		&stubTxRepo{
			findByIdempotencyKeyFn: func(_ context.Context, _ string) (*entity.Transaction, error) { return nil, errNotFound },
		},
	)

	_, err := uc.Pay(context.Background(), usecase.PayInput{
		FromUserID: userID, ShipmentID: uuid.New(), Amount: "100.0000", IdempotencyKey: "pay-insuf",
	})
	if err == nil || err.Error() != "insufficient balance" {
		t.Fatalf("expected 'insufficient balance', got %v", err)
	}
}

func TestPay_Success(t *testing.T) {
	userID := uuid.New()
	w := makeWallet(userID, "500.0000", 0)

	uc := usecase.New(
		&stubWalletRepo{
			findByUserIDFn:  func(_ context.Context, _ uuid.UUID) (*entity.Wallet, error) { return w, nil },
			debitWithLockFn: func(_ context.Context, _ uuid.UUID, _ string, _ int) error { return nil },
		},
		&stubTxRepo{
			findByIdempotencyKeyFn: func(_ context.Context, _ string) (*entity.Transaction, error) { return nil, errNotFound },
			createFn:               noopTxCreate,
		},
	)

	tx, err := uc.Pay(context.Background(), usecase.PayInput{
		FromUserID: userID, ShipmentID: uuid.New(), Amount: "100.0000", IdempotencyKey: "pay-ok",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tx.Type != entity.TxPayment {
		t.Errorf("expected TxPayment, got %s", tx.Type)
	}
}

func TestPay_InvalidAmount(t *testing.T) {
	txRepo := &stubTxRepo{
		findByIdempotencyKeyFn: func(_ context.Context, _ string) (*entity.Transaction, error) { return nil, errNotFound },
	}
	uc := usecase.New(&stubWalletRepo{}, txRepo)
	_, err := uc.Pay(context.Background(), usecase.PayInput{
		FromUserID: uuid.New(), ShipmentID: uuid.New(), Amount: "0", IdempotencyKey: "pay-zero",
	})
	if err == nil {
		t.Fatal("expected error for zero amount")
	}
}

// ── GetBalance ────────────────────────────────────────────────────────────────

func TestGetBalance_Success(t *testing.T) {
	userID := uuid.New()
	w := makeWallet(userID, "250.0000", 1)

	uc := usecase.New(
		&stubWalletRepo{
			findByUserIDFn: func(_ context.Context, _ uuid.UUID) (*entity.Wallet, error) { return w, nil },
		},
		&stubTxRepo{},
	)

	got, err := uc.GetBalance(context.Background(), userID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Balance != "250.0000" {
		t.Errorf("expected balance 250.0000, got %s", got.Balance)
	}
}

func TestGetBalance_NotFound(t *testing.T) {
	uc := usecase.New(
		&stubWalletRepo{
			findByUserIDFn: func(_ context.Context, _ uuid.UUID) (*entity.Wallet, error) { return nil, errNotFound },
		},
		&stubTxRepo{},
	)
	_, err := uc.GetBalance(context.Background(), uuid.New())
	if err == nil {
		t.Fatal("expected error for missing wallet")
	}
}

// ── EnsureWallet ──────────────────────────────────────────────────────────────

func TestEnsureWallet_ReturnsExisting(t *testing.T) {
	userID := uuid.New()
	w := makeWallet(userID, "100.0000", 2)

	uc := usecase.New(
		&stubWalletRepo{
			findByUserIDFn: func(_ context.Context, _ uuid.UUID) (*entity.Wallet, error) { return w, nil },
		},
		&stubTxRepo{},
	)

	got, err := uc.EnsureWallet(context.Background(), userID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Balance != "100.0000" {
		t.Errorf("expected existing balance 100.0000, got %s", got.Balance)
	}
}

func TestEnsureWallet_CreatesNew(t *testing.T) {
	userID := uuid.New()
	uc := usecase.New(
		&stubWalletRepo{
			findByUserIDFn: func(_ context.Context, _ uuid.UUID) (*entity.Wallet, error) { return nil, errNotFound },
			createFn:       func(_ context.Context, _ *entity.Wallet) error { return nil },
		},
		&stubTxRepo{},
	)

	got, err := uc.EnsureWallet(context.Background(), userID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Balance != "0.0000" {
		t.Errorf("expected 0.0000 for new wallet, got %s", got.Balance)
	}
	if got.Currency != "THB" {
		t.Errorf("expected THB, got %s", got.Currency)
	}
}

func TestEnsureWallet_CreateError(t *testing.T) {
	uc := usecase.New(
		&stubWalletRepo{
			findByUserIDFn: func(_ context.Context, _ uuid.UUID) (*entity.Wallet, error) { return nil, errNotFound },
			createFn:       func(_ context.Context, _ *entity.Wallet) error { return errors.New("db error") },
		},
		&stubTxRepo{},
	)

	_, err := uc.EnsureWallet(context.Background(), uuid.New())
	if err == nil {
		t.Fatal("expected error when Create fails")
	}
}

// ── ListTransactions ──────────────────────────────────────────────────────────

func TestListTransactions_ReturnsSlice(t *testing.T) {
	txs := []*entity.Transaction{
		{ID: uuid.New(), Type: entity.TxTopUp, Amount: "100.0000"},
		{ID: uuid.New(), Type: entity.TxPayment, Amount: "-50.0000"},
	}

	uc := usecase.New(
		&stubWalletRepo{},
		&stubTxRepo{
			listFn: func(_ context.Context, _ port.ListQuery) ([]*entity.Transaction, string, error) {
				return txs, "", nil
			},
		},
	)

	got, cursor, err := uc.ListTransactions(context.Background(), port.ListQuery{Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got) != 2 {
		t.Errorf("expected 2 transactions, got %d", len(got))
	}
	if cursor != "" {
		t.Errorf("expected empty cursor, got %q", cursor)
	}
}
