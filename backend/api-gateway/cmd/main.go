package main

import (
	"context"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joho/godotenv"

	"github.com/chanon/ultra-sync/api-gateway/internal/middleware"
	"github.com/chanon/ultra-sync/api-gateway/internal/proxy"
	"github.com/chanon/ultra-sync/pkg/logger"
	"github.com/chanon/ultra-sync/pkg/tracing"
	"github.com/gin-gonic/gin"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
	"go.uber.org/zap"
	"golang.org/x/time/rate"
)

const serviceName = "api-gateway"

func main() {
	_ = godotenv.Load()

	env := getEnv("APP_ENV", "development")
	log := logger.Must(env)
	defer log.Sync() //nolint:errcheck

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	shutdownTracing, err := tracing.Init(ctx, serviceName, getEnv("OTLP_ENDPOINT", "localhost:4318"))
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

	// Fetch the RSA public key from the auth service (retry until ready).
	authPublicKey, err := fetchAuthPublicKey(
		ctx,
		getEnv("AUTH_SERVICE_URL", "http://localhost:8081"),
		log,
	)
	if err != nil {
		log.Fatal("fetch auth public key", zap.Error(err))
	}
	log.Info("loaded RSA public key from auth service")

	if env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.RedirectTrailingSlash = false
	router.Use(otelgin.Middleware(serviceName))
	router.Use(gin.Recovery())
	router.Use(corsMiddleware())
	router.Use(rateLimitMiddleware(rate.NewLimiter(rate.Limit(100), 200)))

	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": serviceName})
	})

	// Public routes — no JWT required.
	router.Any("/api/v1/auth/*path", rp.Forward("auth"))

	// Protected routes — JWT verification applied.
	protected := router.Group("/")
	protected.Use(middleware.JWT(authPublicKey))

	// Register both base path and sub-paths so requests without trailing slash are not 307-redirected.
	shipmentsGroup := protected.Group("/api/v1/shipments")
	shipmentsGroup.Any("", rp.Forward("logistics"))
	shipmentsGroup.Any("/*path", rp.Forward("logistics"))

	walletGroup := protected.Group("/api/v1/wallet")
	walletGroup.Any("", rp.Forward("wallet"))
	walletGroup.Any("/*path", rp.Forward("wallet"))

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

// fetchAuthPublicKey polls the auth service for its RSA public key, retrying
// with linear backoff until the service is reachable (handles startup ordering).
func fetchAuthPublicKey(ctx context.Context, authURL string, log *zap.Logger) (*rsa.PublicKey, error) {
	endpoint := authURL + "/api/v1/auth/public-key"
	client := &http.Client{Timeout: 5 * time.Second}

	for attempt := 1; attempt <= 10; attempt++ {
		key, err := tryFetchKey(ctx, client, endpoint)
		if err == nil {
			return key, nil
		}
		log.Warn("auth service not ready, retrying",
			zap.Int("attempt", attempt), zap.Error(err))
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(time.Duration(attempt) * time.Second):
		}
	}

	return nil, fmt.Errorf("auth service unreachable after 10 attempts")
}

func tryFetchKey(ctx context.Context, client *http.Client, endpoint string) (*rsa.PublicKey, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	block, _ := pem.Decode(body)
	if block == nil {
		return nil, fmt.Errorf("failed to decode PEM block")
	}

	pub, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse public key: %w", err)
	}

	rsaPub, ok := pub.(*rsa.PublicKey)
	if !ok {
		return nil, fmt.Errorf("expected RSA public key, got %T", pub)
	}
	return rsaPub, nil
}

func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type,Authorization,X-Idempotency-Key")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
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
