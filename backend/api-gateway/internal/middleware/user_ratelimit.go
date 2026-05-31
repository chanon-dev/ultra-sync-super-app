package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

type userLimiter struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// UserRateLimit returns a gin middleware that enforces per-user rate limits using
// an in-memory map of token-bucket limiters. Inactive entries are purged every minute.
func UserRateLimit(rps rate.Limit, burst int) gin.HandlerFunc {
	var (
		mu      sync.Mutex
		entries = make(map[string]*userLimiter)
	)

	// Background cleanup: remove limiters that haven't been used in 5 minutes.
	go func() {
		for range time.Tick(time.Minute) {
			mu.Lock()
			for id, ul := range entries {
				if time.Since(ul.lastSeen) > 5*time.Minute {
					delete(entries, id)
				}
			}
			mu.Unlock()
		}
	}()

	getLimiter := func(userID string) *rate.Limiter {
		mu.Lock()
		defer mu.Unlock()
		ul, ok := entries[userID]
		if !ok {
			ul = &userLimiter{limiter: rate.NewLimiter(rps, burst)}
			entries[userID] = ul
		}
		ul.lastSeen = time.Now()
		return ul.limiter
	}

	return func(c *gin.Context) {
		userID := c.GetHeader("X-User-ID")
		if userID == "" {
			// No authenticated user yet (public route) — skip per-user check.
			c.Next()
			return
		}

		if !getLimiter(userID).Allow() {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": gin.H{
					"code":    "RATE-001",
					"message": "per-user rate limit exceeded",
				},
			})
			return
		}

		c.Next()
	}
}
