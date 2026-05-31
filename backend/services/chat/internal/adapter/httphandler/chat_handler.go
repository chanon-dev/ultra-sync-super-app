package httphandler

import (
	"context"
	"io"
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
		return true
	},
}

const maxUploadBytes = 10 << 20 // 10 MB

type ChatUseCase interface {
	LoadHistory(ctx context.Context, roomID uuid.UUID, limit int, beforeID *uuid.UUID) ([]*domain.ChatMessage, error)
	SendMessage(ctx context.Context, senderID uuid.UUID, senderRole string, roomID uuid.UUID, content string) (*domain.ChatMessage, error)
	SubscribeRoom(ctx context.Context, roomID uuid.UUID) (<-chan *domain.ChatMessage, func(), error)
	CreateRoom(ctx context.Context, name string, createdBy uuid.UUID) (*domain.ChatRoom, error)
	GetRoom(ctx context.Context, id uuid.UUID) (*domain.ChatRoom, error)
	ListRooms(ctx context.Context, userID uuid.UUID, limit int, afterID *uuid.UUID) ([]*domain.ChatRoom, error)
	JoinRoom(ctx context.Context, roomID, userID uuid.UUID) error
	UploadAttachment(ctx context.Context, filename string, data []byte, contentType string) (string, error)
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
		group.POST("/rooms", h.CreateRoom)
		group.GET("/rooms", h.ListRooms)
		group.GET("/rooms/:room_id", h.GetRoom)
		group.POST("/rooms/:room_id/join", h.JoinRoom)
		group.POST("/rooms/:room_id/upload", h.UploadAttachment)
	}
}

func (h *ChatHandler) CreateRoom(c *gin.Context) {
	userID, ok := userIDFromHeader(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req struct {
		Name string `json:"name" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	room, err := h.uc.CreateRoom(c.Request.Context(), req.Name, userID)
	if err != nil {
		h.log.Error("create room failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"data": room})
}

func (h *ChatHandler) GetRoom(c *gin.Context) {
	roomID, err := uuid.Parse(c.Param("room_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid room id"})
		return
	}

	room, err := h.uc.GetRoom(c.Request.Context(), roomID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "room not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": room})
}

func (h *ChatHandler) ListRooms(c *gin.Context) {
	userID, ok := userIDFromHeader(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	limit := parseLimit(c.DefaultQuery("limit", "20"))

	var afterID *uuid.UUID
	if afterStr := c.Query("after"); afterStr != "" {
		id, err := uuid.Parse(afterStr)
		if err == nil {
			afterID = &id
		}
	}

	rooms, err := h.uc.ListRooms(c.Request.Context(), userID, limit, afterID)
	if err != nil {
		h.log.Error("list rooms failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list rooms"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data": rooms,
		"meta": gin.H{"count": len(rooms)},
	})
}

func (h *ChatHandler) JoinRoom(c *gin.Context) {
	roomID, err := uuid.Parse(c.Param("room_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid room id"})
		return
	}

	userID, ok := userIDFromHeader(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	if err := h.uc.JoinRoom(c.Request.Context(), roomID, userID); err != nil {
		h.log.Error("join room failed", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": gin.H{"joined": true}})
}

func (h *ChatHandler) UploadAttachment(c *gin.Context) {
	roomID, err := uuid.Parse(c.Param("room_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid room id"})
		return
	}
	_ = roomID

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxUploadBytes)

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "file required"})
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to read file"})
		return
	}

	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	url, err := h.uc.UploadAttachment(c.Request.Context(), header.Filename, data, contentType)
	if err != nil {
		h.log.Error("upload attachment failed", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": gin.H{"url": url}})
}

func (h *ChatHandler) LoadHistory(c *gin.Context) {
	roomIDStr := c.Param("room_id")
	roomID, err := uuid.Parse(roomIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid room id"})
		return
	}

	limit := parseLimit(c.DefaultQuery("limit", "20"))

	var beforeID *uuid.UUID
	if beforeStr := c.Query("before"); beforeStr != "" {
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
		"meta": gin.H{"limit": limit, "count": len(messages)},
	})
}

func (h *ChatHandler) UpgradeWebSocket(c *gin.Context) {
	roomIDStr := c.Param("room_id")
	roomID, err := uuid.Parse(roomIDStr)
	if err != nil {
		c.String(http.StatusBadRequest, "invalid room id")
		return
	}

	userIDStr := c.GetHeader("X-User-ID")
	userRole := c.GetHeader("X-User-Role")
	if userIDStr == "" {
		userIDStr = c.Query("user_id")
		userRole = c.DefaultQuery("role", "user")
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil || userID == uuid.Nil {
		h.log.Warn("websocket upgrade rejected: unauthorized, missing X-User-ID header")
		c.String(http.StatusUnauthorized, "unauthorized")
		return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		h.log.Error("websocket upgrade failed", zap.Error(err))
		return
	}
	defer conn.Close()

	h.log.Info("websocket connection established", zap.String("userID", userIDStr), zap.String("room", roomIDStr))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	redisChan, unsubscribe, err := h.uc.SubscribeRoom(ctx, roomID)
	if err != nil {
		h.log.Error("failed to subscribe to redis pubsub room", zap.String("room", roomIDStr), zap.Error(err))
		return
	}
	defer unsubscribe()

	var wg sync.WaitGroup
	var connMu sync.Mutex

	wg.Add(1)
	go func() {
		defer wg.Done()
		defer cancel()

		for {
			var payload struct {
				Content string `json:"content"`
			}
			_ = conn.SetReadDeadline(time.Now().Add(60 * time.Second))
			if err := conn.ReadJSON(&payload); err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					h.log.Error("websocket read error", zap.Error(err))
				}
				break
			}

			if payload.Content == "" {
				continue
			}

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

	wg.Add(1)
	go func() {
		defer wg.Done()

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

func userIDFromHeader(c *gin.Context) (uuid.UUID, bool) {
	str := c.GetHeader("X-User-ID")
	if str == "" {
		return uuid.Nil, false
	}
	id, err := uuid.Parse(str)
	if err != nil || id == uuid.Nil {
		return uuid.Nil, false
	}
	return id, true
}

func parseLimit(s string) int {
	n := 0
	for _, ch := range s {
		if ch < '0' || ch > '9' {
			return 20
		}
		n = n*10 + int(ch-'0')
	}
	if n <= 0 {
		return 20
	}
	return n
}
