package httphandler

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"net/http"

	"github.com/chanon/ultra-sync/pkg/response"
	"github.com/chanon/ultra-sync/services/auth/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/auth/internal/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	auth         *usecase.AuthUseCase
	rsaPublicKey *rsa.PublicKey
}

func New(auth *usecase.AuthUseCase, rsaPublicKey *rsa.PublicKey) *Handler {
	return &Handler{auth: auth, rsaPublicKey: rsaPublicKey}
}

func (h *Handler) Register(r gin.IRouter) {
	v1 := r.Group("/api/v1/auth")
	v1.POST("/register", h.register)
	v1.POST("/login", h.login)
	v1.POST("/refresh", h.refresh)
	v1.POST("/logout", h.logout)
	v1.GET("/public-key", h.getPublicKey)

	// Profile (requires gateway JWT middleware — X-User-ID injected)
	v1.GET("/me", h.getProfile)
	v1.PATCH("/me", h.updateProfile)

	// Admin (requires role=admin via gateway)
	admin := r.Group("/api/v1/admin")
	admin.Use(h.requireAdmin())
	admin.GET("/users", h.adminListUsers)
	admin.PATCH("/users/:id/status", h.adminUpdateUserStatus)
}

// GET /api/v1/auth/public-key returns the RSA public key in PEM format.
// Used by the API Gateway on startup to bootstrap JWT verification.
func (h *Handler) getPublicKey(c *gin.Context) {
	der, err := x509.MarshalPKIXPublicKey(h.rsaPublicKey)
	if err != nil {
		response.Internal(c)
		return
	}
	c.Header("Content-Type", "application/x-pem-file")
	if err := pem.Encode(c.Writer, &pem.Block{Type: "PUBLIC KEY", Bytes: der}); err != nil {
		response.Internal(c)
	}
}

// POST /api/v1/auth/register
func (h *Handler) register(c *gin.Context) {
	var req struct {
		Email    string `json:"email"    binding:"required,email"`
		Password string `json:"password" binding:"required,min=8"`
		Role     string `json:"role"     binding:"required,oneof=user driver"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	user, err := h.auth.Register(c.Request.Context(), usecase.RegisterInput{
		Email:    req.Email,
		Password: req.Password,
		Role:     entity.Role(req.Role),
	})
	if err != nil {
		response.BadRequest(c, "AUTH-010", err.Error())
		return
	}

	response.Created(c, gin.H{
		"user_id": user.ID,
		"email":   user.Email,
		"status":  user.Status,
	})
}

// POST /api/v1/auth/login
func (h *Handler) login(c *gin.Context) {
	var req struct {
		Email    string `json:"email"    binding:"required,email"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	tokens, err := h.auth.Login(c.Request.Context(), usecase.LoginInput{
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": gin.H{"code": "AUTH-002", "message": err.Error()},
		})
		return
	}

	response.OK(c, tokens)
}

// POST /api/v1/auth/refresh
func (h *Handler) refresh(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	tokens, err := h.auth.RefreshToken(c.Request.Context(), req.RefreshToken)
	if err != nil {
		response.Unauthorized(c)
		return
	}

	response.OK(c, tokens)
}

// POST /api/v1/auth/logout
func (h *Handler) logout(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	_ = h.auth.Logout(c.Request.Context(), req.RefreshToken)
	response.OK(c, gin.H{"success": true})
}

// GET /api/v1/auth/me
func (h *Handler) getProfile(c *gin.Context) {
	userID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}
	user, err := h.auth.GetProfile(c.Request.Context(), userID)
	if err != nil {
		response.Internal(c)
		return
	}
	response.OK(c, userJSON(user))
}

// PATCH /api/v1/auth/me
func (h *Handler) updateProfile(c *gin.Context) {
	userID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}
	var req struct {
		DisplayName string `json:"display_name"`
		AvatarURL   string `json:"avatar_url"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}
	user, err := h.auth.UpdateProfile(c.Request.Context(), usecase.UpdateProfileInput{
		UserID:      userID,
		DisplayName: req.DisplayName,
		AvatarURL:   req.AvatarURL,
	})
	if err != nil {
		response.BadRequest(c, "AUTH-020", err.Error())
		return
	}
	response.OK(c, userJSON(user))
}

// requireAdmin is a gin middleware that aborts with 403 unless X-User-Role == "admin".
func (h *Handler) requireAdmin() gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.GetHeader("X-User-Role") != "admin" {
			c.JSON(http.StatusForbidden, gin.H{
				"error": gin.H{"code": "AUTH-003", "message": "admin role required"},
			})
			c.Abort()
			return
		}
		c.Next()
	}
}

// GET /api/v1/admin/users
func (h *Handler) adminListUsers(c *gin.Context) {
	status := c.Query("status")
	after := c.Query("after")
	limit := parseLimit(c.DefaultQuery("limit", "20"))

	users, nextCursor, err := h.auth.AdminListUsers(c.Request.Context(), status, limit, after)
	if err != nil {
		response.Internal(c)
		return
	}

	result := make([]gin.H, 0, len(users))
	for _, u := range users {
		result = append(result, userJSON(u))
	}
	c.JSON(http.StatusOK, gin.H{
		"data": result,
		"meta": gin.H{"next_cursor": nextCursor},
	})
}

// PATCH /api/v1/admin/users/:id/status
func (h *Handler) adminUpdateUserStatus(c *gin.Context) {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "VAL-001", "invalid user id")
		return
	}
	var req struct {
		Status string `json:"status" binding:"required,oneof=active suspended pending_verify"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}
	if err := h.auth.AdminUpdateUserStatus(c.Request.Context(), targetID, entity.UserStatus(req.Status)); err != nil {
		response.Internal(c)
		return
	}
	response.OK(c, gin.H{"updated": true})
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

func userJSON(u *entity.User) gin.H {
	return gin.H{
		"id":           u.ID,
		"email":        u.Email,
		"display_name": u.DisplayName,
		"avatar_url":   u.AvatarURL,
		"role":         u.Role,
		"status":       u.Status,
		"created_at":   u.CreatedAt,
	}
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
