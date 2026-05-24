package httphandler

import (
	"context"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"go.uber.org/zap"

	"github.com/chanon/ultra-sync/services/chat/internal/domain"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for dev / mobile clients
	},
}

type ChatUseCase interface {
	LoadHistory(ctx context.Context, roomID uuid.UUID, limit int, beforeID *uuid.UUID) ([]*domain.ChatMessage, error)
	SendMessage(ctx context.Context, senderID uuid.UUID, senderRole string, roomID uuid.UUID, content string) (*domain.ChatMessage, error)
	SubscribeRoom(ctx context.Context, roomID uuid.UUID) (<-chan *domain.ChatMessage, func(), error)
}

type ChatHandler struct {
	uc  ChatUseCase
	log *zap.Logger
}

func New(uc ChatUseCase, log *zap.Logger) *ChatHandler {
	return &ChatHandler{uc: uc, log: log}
}

func (h *ChatHandler) Register(r *gin.Engine) {
	group := r.Group("/api/v1/chat")
	{
		group.GET("/rooms/:room_id/messages", h.LoadHistory)
		group.GET("/ws/:room_id", h.UpgradeWebSocket)
	}
}

func (h *ChatHandler) LoadHistory(c *gin.Context) {
	roomIDStr := c.Param("room_id")
	roomID, err := uuid.Parse(roomIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid room id"})
		return
	}

	limitStr := c.DefaultQuery("limit", "20")
	var limit int
	if _, err := fmtSscanf(limitStr, "%d", &limit); err != nil || limit <= 0 {
		limit = 20
	}

	var beforeID *uuid.UUID
	beforeStr := c.Query("before")
	if beforeStr != "" {
		bid, err := uuid.Parse(beforeStr)
		if err == nil {
			beforeID = &bid
		}
	}

	messages, err := h.uc.LoadHistory(c.Request.Context(), roomID, limit, beforeID)
	if err != nil {
		h.log.Error("failed to load chat history", zap.String("room", roomIDStr), zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load chat history"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data": messages,
		"meta": gin.H{
			"limit": limit,
			"count": len(messages),
		},
	})
}

func (h *ChatHandler) UpgradeWebSocket(c *gin.Context) {
	roomIDStr := c.Param("room_id")
	roomID, err := uuid.Parse(roomIDStr)
	if err != nil {
		c.String(http.StatusBadRequest, "invalid room id")
		return
	}

	// 1. Identify User from Gateway trusted headers
	userIDStr := c.GetHeader("X-User-ID")
	userRole := c.GetHeader("X-User-Role")

	if userIDStr == "" {
		// Fallback to query parameter if headers are empty (e.g. testing directly in browser)
		userIDStr = c.Query("user_id")
		userRole = c.DefaultQuery("role", "user")
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil || userID == uuid.Nil {
		h.log.Warn("websocket upgrade rejected: unauthorized, missing X-User-ID header")
		c.String(http.StatusUnauthorized, "unauthorized")
		return
	}

	// Upgrade the HTTP request to WebSocket
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		h.log.Error("websocket upgrade failed", zap.Error(err))
		return
	}
	defer conn.Close()

	h.log.Info("websocket connection established", zap.String("userID", userIDStr), zap.String("room", roomIDStr))

	// Subscribe to Redis Pub/Sub room
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	redisChan, unsubscribe, err := h.uc.SubscribeRoom(ctx, roomID)
	if err != nil {
		h.log.Error("failed to subscribe to redis pubsub room", zap.String("room", roomIDStr), zap.Error(err))
		return
	}
	defer unsubscribe()

	// Goroutine logic sync using WaitGroup and Mutex
	var wg sync.WaitGroup
	var connMu sync.Mutex

	// Read loop: receive from Client -> Publish to Redis & Kafka
	wg.Add(1)
	go func() {
		defer wg.Done()
		defer cancel() // cancel the context to stop the write loop if client disconnects

		for {
			var payload struct {
				Content string `json:"content"`
			}

			// Configure read limit & deadline
			_ = conn.SetReadDeadline(time.Now().Add(60 * time.Second))
			err := conn.ReadJSON(&payload)
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					h.log.Error("websocket read error", zap.Error(err))
				}
				break
			}

			if payload.Content == "" {
				continue
			}

			// Broadcast message via Usecase (ephemeral Redis + durable Kafka)
			sendCtx, sendCancel := context.WithTimeout(context.Background(), 5*time.Second)
			_, err = h.uc.SendMessage(sendCtx, userID, userRole, roomID, payload.Content)
			sendCancel()
			if err != nil {
				h.log.Error("failed to process sent message", zap.Error(err))
				connMu.Lock()
				_ = conn.WriteJSON(gin.H{"error": "failed to send message"})
				connMu.Unlock()
			}
		}
	}()

	// Write loop: receive from Redis Pub/Sub -> Send to Client
	wg.Add(1)
	go func() {
		defer wg.Done()

		// Set up simple ping ticker to keep WebSocket connection alive
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case msg, ok := <-redisChan:
				if !ok {
					return
				}
				connMu.Lock()
				_ = conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
				err := conn.WriteJSON(msg)
				connMu.Unlock()
				if err != nil {
					h.log.Error("websocket write message error", zap.Error(err))
					return
				}
			case <-ticker.C:
				connMu.Lock()
				_ = conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
				err := conn.WriteMessage(websocket.PingMessage, nil)
				connMu.Unlock()
				if err != nil {
					return
				}
			}
		}
	}()

	wg.Wait()
	h.log.Info("websocket connection closed gracefully", zap.String("userID", userIDStr), zap.String("room", roomIDStr))
}

func fmtSscanf(str string, format string, a ...any) (int, error) {
	// Simple helper to parse limit parameter
	var val int
	n, err := fmtSscanfParser(str, &val)
	if len(a) > 0 {
		if ptr, ok := a[0].(*int); ok {
			*ptr = val
		}
	}
	return n, err
}

func fmtSscanfParser(str string, val *int) (int, error) {
	var num int
	for _, char := range str {
		if char < '0' || char > '9' {
			return 0, http.ErrBodyNotAllowed
		}
		num = num*10 + int(char-'0')
	}
	*val = num
	return 1, nil
}
