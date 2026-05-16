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
)

type Handler struct {
	uc *usecase.WalletUseCase
}

func New(uc *usecase.WalletUseCase) *Handler {
	return &Handler{uc: uc}
}

func (h *Handler) Register(r gin.IRouter) {
	v1 := r.Group("/api/v1/wallet")
	v1.GET("/balance", h.getBalance)
	v1.POST("/topup", h.topUp)
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

	idempotencyKey := c.GetHeader("X-Idempotency-Key")
	if idempotencyKey == "" {
		response.BadRequest(c, "VAL-001", "X-Idempotency-Key header is required")
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
