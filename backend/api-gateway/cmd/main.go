package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/chanon/ultra-sync/api-gateway/internal/proxy"
	"github.com/chanon/ultra-sync/pkg/logger"
	"github.com/chanon/ultra-sync/pkg/tracing"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"golang.org/x/time/rate"
)

func main() {
	env := getEnv("APP_ENV", "development")
	log := logger.Must(env)
	defer log.Sync() //nolint:errcheck

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	shutdownTracing, err := tracing.Init(ctx, "api-gateway", getEnv("OTLP_ENDPOINT", "localhost:4318"))
	if err != nil {
		log.Warn("tracing init failed", zap.Error(err))
	} else {
		defer shutdownTracing(ctx) //nolint:errcheck
	}

	services := []proxy.ServiceConfig{
		{Name: "auth",      URL: getEnv("AUTH_SERVICE_URL",      "http://localhost:8081")},
		{Name: "logistics", URL: getEnv("LOGISTICS_SERVICE_URL", "http://localhost:8082")},
		{Name: "wallet",    URL: getEnv("WALLET_SERVICE_URL",    "http://localhost:8083")},
	}

	rp, err := proxy.New(services, log)
	if err != nil {
		log.Fatal("init reverse proxy", zap.Error(err))
	}

	if env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(rateLimitMiddleware(rate.NewLimiter(rate.Limit(100), 200)))

	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "api-gateway"})
	})

	// Auth routes (public — no JWT required)
	router.Any("/api/v1/auth/*path", rp.Forward("auth"))

	// Protected routes (Phase 2: add JWT middleware here)
	router.Any("/api/v1/shipments/*path", rp.Forward("logistics"))
	router.Any("/api/v1/wallet/*path",    rp.Forward("wallet"))

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", getEnv("PORT", "8080")),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Info("api-gateway starting", zap.String("addr", srv.Addr))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("listen", zap.Error(err))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("shutting down api-gateway...")
	shutCtx, shutCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutCancel()
	srv.Shutdown(shutCtx) //nolint:errcheck
}

func rateLimitMiddleware(limiter *rate.Limiter) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !limiter.Allow() {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": gin.H{"code": "GW-429", "message": "rate limit exceeded"},
			})
			return
		}
		c.Next()
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
