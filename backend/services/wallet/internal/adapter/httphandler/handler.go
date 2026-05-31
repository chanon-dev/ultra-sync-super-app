package httphandler

import (
	"net/http"
	"strconv"

	"github.com/chanon/ultra-sync/pkg/response"
	"github.com/chanon/ultra-sync/services/wallet/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/wallet/internal/domain/port"
	"github.com/chanon/ultra-sync/services/wallet/internal/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

const (
	headerIdempotencyKey = "X-Idempotency-Key"
	errIdempotencyKeyReq = "X-Idempotency-Key header is required"
	errCodeValidation    = "VAL-001"
)

type Handler struct {
	uc  *usecase.WalletUseCase
	log *zap.Logger
}

func New(uc *usecase.WalletUseCase, log *zap.Logger) *Handler {
	return &Handler{uc: uc, log: log}
}

func (h *Handler) Register(r gin.IRouter) {
	v1 := r.Group("/api/v1/wallet")
	v1.GET("/balance", h.getBalance)
	v1.POST("/topup", h.topUp)
	v1.POST("/pay", h.pay)
	v1.POST("/transfer", h.transfer)
	v1.POST("/payout", h.payout)
	v1.GET("/transactions", h.listTransactions)
}

// GET /api/v1/wallet/balance — auto-provisions wallet on first call.
func (h *Handler) getBalance(c *gin.Context) {
	userID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}

	wallet, err := h.uc.EnsureWallet(c.Request.Context(), userID)
	if err != nil {
		response.Internal(c)
		return
	}

	response.OK(c, walletJSON(wallet))
}

// POST /api/v1/wallet/topup — requires X-Idempotency-Key header.
func (h *Handler) topUp(c *gin.Context) {
	userID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}

	idempotencyKey := c.GetHeader(headerIdempotencyKey)
	if idempotencyKey == "" {
		response.BadRequest(c, "VAL-001", errIdempotencyKeyReq)
		return
	}

	var req struct {
		Amount string `json:"amount" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	if _, err := h.uc.EnsureWallet(c.Request.Context(), userID); err != nil {
		response.Internal(c)
		return
	}

	tx, err := h.uc.TopUp(c.Request.Context(), usecase.TopUpInput{
		UserID:         userID,
		Amount:         req.Amount,
		IdempotencyKey: idempotencyKey,
	})
	if err != nil {
		response.Err(c, http.StatusUnprocessableEntity, "WAL-001", err.Error())
		return
	}

	h.log.Info("audit: wallet.topup",
		zap.String("user_id", userID.String()),
		zap.String("tx_id", tx.ID.String()),
		zap.String("amount", tx.Amount),
		zap.String("balance_after", tx.BalanceAfter),
		zap.String("idempotency_key", idempotencyKey),
	)
	response.Created(c, transactionJSON(tx))
}

// POST /api/v1/wallet/pay — debit wallet for a delivered shipment (called by Saga orchestrator).
func (h *Handler) pay(c *gin.Context) {
	userID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}

	idempotencyKey := c.GetHeader(headerIdempotencyKey)
	if idempotencyKey == "" {
		response.BadRequest(c, "VAL-001", errIdempotencyKeyReq)
		return
	}

	var req struct {
		ShipmentID string `json:"shipment_id" binding:"required"`
		Amount     string `json:"amount"      binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	shipmentID, err := uuid.Parse(req.ShipmentID)
	if err != nil {
		response.BadRequest(c, "VAL-002", "invalid shipment_id")
		return
	}

	tx, err := h.uc.Pay(c.Request.Context(), usecase.PayInput{
		FromUserID:     userID,
		ShipmentID:     shipmentID,
		Amount:         req.Amount,
		IdempotencyKey: idempotencyKey,
	})
	if err != nil {
		if err.Error() == "insufficient balance" {
			response.Err(c, http.StatusUnprocessableEntity, "WAL-002", err.Error())
			return
		}
		response.Err(c, http.StatusUnprocessableEntity, "WAL-001", err.Error())
		return
	}

	h.log.Info("audit: wallet.pay",
		zap.String("user_id", userID.String()),
		zap.String("shipment_id", req.ShipmentID),
		zap.String("tx_id", tx.ID.String()),
		zap.String("amount", tx.Amount),
		zap.String("balance_after", tx.BalanceAfter),
		zap.String("idempotency_key", idempotencyKey),
	)
	response.OK(c, transactionJSON(tx))
}

// POST /api/v1/wallet/transfer — P2P transfer between two user wallets.
func (h *Handler) transfer(c *gin.Context) {
	fromUserID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}

	idempotencyKey := c.GetHeader(headerIdempotencyKey)
	if idempotencyKey == "" {
		response.BadRequest(c, "VAL-001", errIdempotencyKeyReq)
		return
	}

	var req struct {
		ToUserID string `json:"to_user_id" binding:"required"`
		Amount   string `json:"amount"     binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	toUserID, err := uuid.Parse(req.ToUserID)
	if err != nil {
		response.BadRequest(c, "VAL-002", "invalid to_user_id")
		return
	}

	tx, err := h.uc.Transfer(c.Request.Context(), usecase.TransferInput{
		FromUserID:     fromUserID,
		ToUserID:       toUserID,
		Amount:         req.Amount,
		IdempotencyKey: idempotencyKey,
	})
	if err != nil {
		response.Err(c, http.StatusUnprocessableEntity, "WAL-003", err.Error())
		return
	}

	h.log.Info("audit: wallet.transfer",
		zap.String("from_user_id", fromUserID.String()),
		zap.String("to_user_id", req.ToUserID),
		zap.String("tx_id", tx.ID.String()),
		zap.String("amount", tx.Amount),
		zap.String("idempotency_key", idempotencyKey),
	)
	response.Created(c, transactionJSON(tx))
}

// POST /api/v1/wallet/payout — debit wallet and initiate payout to bank account.
func (h *Handler) payout(c *gin.Context) {
	userID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}

	idempotencyKey := c.GetHeader(headerIdempotencyKey)
	if idempotencyKey == "" {
		response.BadRequest(c, "VAL-001", errIdempotencyKeyReq)
		return
	}

	var req struct {
		Amount      string `json:"amount"       binding:"required"`
		BankAccount string `json:"bank_account" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	tx, err := h.uc.Payout(c.Request.Context(), usecase.PayoutInput{
		UserID:         userID,
		Amount:         req.Amount,
		BankAccount:    req.BankAccount,
		IdempotencyKey: idempotencyKey,
	})
	if err != nil {
		response.Err(c, http.StatusUnprocessableEntity, "WAL-004", err.Error())
		return
	}

	h.log.Info("audit: wallet.payout",
		zap.String("user_id", userID.String()),
		zap.String("bank_account", req.BankAccount),
		zap.String("tx_id", tx.ID.String()),
		zap.String("amount", tx.Amount),
		zap.String("idempotency_key", idempotencyKey),
	)
	response.Created(c, transactionJSON(tx))
}

// GET /api/v1/wallet/transactions — cursor-paginated transaction history.
func (h *Handler) listTransactions(c *gin.Context) {
	userID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	txs, nextCursor, err := h.uc.ListTransactions(c.Request.Context(), port.ListQuery{
		WalletID: userID,
		Type:     c.Query("type"),
		After:    c.Query("after"),
		Limit:    limit,
	})
	if err != nil {
		response.Internal(c)
		return
	}

	items := make([]map[string]any, 0, len(txs))
	for _, tx := range txs {
		items = append(items, transactionJSON(tx))
	}
	response.Paginated(c, items, nextCursor, nextCursor != "")
}

func userIDFromHeader(c *gin.Context) (uuid.UUID, bool) {
	raw := c.GetHeader("X-User-ID")
	if raw == "" {
		return uuid.Nil, false
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, false
	}
	return id, true
}

func walletJSON(w *entity.Wallet) map[string]any {
	return map[string]any{
		"user_id":    w.UserID,
		"balance":    w.Balance,
		"currency":   w.Currency,
		"version":    w.Version,
		"updated_at": w.UpdatedAt,
	}
}

func transactionJSON(tx *entity.Transaction) map[string]any {
	m := map[string]any{
		"id":              tx.ID,
		"wallet_id":       tx.WalletID,
		"type":            tx.Type,
		"amount":          tx.Amount,
		"balance_after":   tx.BalanceAfter,
		"idempotency_key": tx.IdempotencyKey,
		"created_at":      tx.CreatedAt,
	}
	if tx.ReferenceID != nil {
		m["reference_id"] = *tx.ReferenceID
	}
	return m
}
