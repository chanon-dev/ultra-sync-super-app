package middleware

import (
	"crypto/rsa"
	"fmt"
	"net/http"
	"strings"

	gojwt "github.com/golang-jwt/jwt/v5"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const (
	ContextKeyUserID = "user_id"
	ContextKeyRole   = "role"
)

type jwtClaims struct {
	UserID string `json:"uid"`
	Email  string `json:"email"`
	Role   string `json:"role"`
	gojwt.RegisteredClaims
}

// JWT returns a middleware that validates RS256 access tokens.
func JWT(publicKey *rsa.PublicKey) gin.HandlerFunc {
	return func(c *gin.Context) {
		token, err := extractBearer(c)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": gin.H{"code": "AUTH-001", "message": "missing or malformed token"},
			})
			return
		}

		claims, err := parseToken(token, publicKey)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": gin.H{"code": "AUTH-001", "message": "invalid token"},
			})
			return
		}

		c.Set(ContextKeyUserID, claims.UserID)
		c.Set(ContextKeyRole, claims.Role)
		c.Next()
	}
}

// RequireRole returns a middleware that enforces a minimum role after JWT.
func RequireRole(roles ...string) gin.HandlerFunc {
	allowed := make(map[string]struct{}, len(roles))
	for _, r := range roles {
		allowed[r] = struct{}{}
	}
	return func(c *gin.Context) {
		role, _ := c.Get(ContextKeyRole)
		if _, ok := allowed[fmt.Sprintf("%v", role)]; !ok {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error": gin.H{"code": "AUTH-002", "message": "forbidden"},
			})
			return
		}
		c.Next()
	}
}

// UserIDFromContext returns the authenticated user's UUID.
func UserIDFromContext(c *gin.Context) (uuid.UUID, bool) {
	raw, exists := c.Get(ContextKeyUserID)
	if !exists {
		return uuid.Nil, false
	}
	id, err := uuid.Parse(fmt.Sprintf("%v", raw))
	if err != nil {
		return uuid.Nil, false
	}
	return id, true
}

func extractBearer(c *gin.Context) (string, error) {
	header := c.GetHeader("Authorization")
	if header == "" {
		return "", fmt.Errorf("missing Authorization header")
	}
	parts := strings.SplitN(header, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return "", fmt.Errorf("malformed Authorization header")
	}
	return parts[1], nil
}

func parseToken(tokenStr string, pubKey *rsa.PublicKey) (*jwtClaims, error) {
	token, err := gojwt.ParseWithClaims(tokenStr, &jwtClaims{}, func(t *gojwt.Token) (any, error) {
		if _, ok := t.Method.(*gojwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return pubKey, nil
	})
	if err != nil {
		return nil, fmt.Errorf("parse token: %w", err)
	}

	claims, ok := token.Claims.(*jwtClaims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid claims")
	}
	return claims, nil
}
