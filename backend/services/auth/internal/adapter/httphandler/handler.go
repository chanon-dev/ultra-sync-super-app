package httphandler

import (
	"net/http"

	"github.com/chanon/ultra-sync/pkg/response"
	"github.com/chanon/ultra-sync/services/auth/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/auth/internal/usecase"
	"github.com/gin-gonic/gin"
)

type Handler struct {
	auth *usecase.AuthUseCase
}

func New(auth *usecase.AuthUseCase) *Handler {
	return &Handler{auth: auth}
}

func (h *Handler) Register(r gin.IRouter) {
	v1 := r.Group("/api/v1/auth")
	v1.POST("/register", h.register)
	v1.POST("/login", h.login)
	v1.POST("/refresh", h.refresh)
	v1.POST("/logout", h.logout)
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
