package main

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joho/godotenv"

	"github.com/chanon/ultra-sync/pkg/logger"
	"github.com/chanon/ultra-sync/pkg/tracing"
	"github.com/chanon/ultra-sync/services/auth/internal/adapter/httphandler"
	authjwt "github.com/chanon/ultra-sync/services/auth/internal/adapter/jwt"
	"github.com/chanon/ultra-sync/services/auth/internal/adapter/postgres"
	"github.com/chanon/ultra-sync/services/auth/internal/adapter/redisstore"
	authvault "github.com/chanon/ultra-sync/services/auth/internal/adapter/vault"
	"github.com/chanon/ultra-sync/services/auth/internal/usecase"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

func main() {
	_ = godotenv.Load()

	env := getEnv("APP_ENV", "development")

	log := logger.Must(env)
	defer log.Sync() //nolint:errcheck

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Tracing
	shutdownTracing, err := tracing.Init(ctx, "auth-service", getEnv("OTLP_ENDPOINT", "localhost:4318"))
	if err != nil {
		log.Warn("tracing init failed, continuing without tracing", zap.Error(err))
	} else {
		defer shutdownTracing(ctx) //nolint:errcheck
	}

	// Database
	dbPool, err := pgxpool.New(ctx, getEnv("AUTH_DB_DSN",
		"postgres://authuser:authpass@localhost:5432/authdb?sslmode=disable"))
	if err != nil {
		log.Fatal("connect to authdb", zap.Error(err))
	}
	defer dbPool.Close()

	if err := dbPool.Ping(ctx); err != nil {
		log.Fatal("ping authdb", zap.Error(err))
	}

	// Redis
	redisOpts, err := redis.ParseURL(getEnv("REDIS_URL", "redis://:redispass@localhost:6379/0"))
	if err != nil {
		log.Fatal("parse redis url", zap.Error(err))
	}
	rdb := redis.NewClient(redisOpts)
	defer rdb.Close()

	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatal("ping redis", zap.Error(err))
	}

	// JWT RSA key: load from Vault when VAULT_ADDR is set; otherwise generate ephemeral.
	var privateKey *rsa.PrivateKey
	if vaultAddr := os.Getenv("VAULT_ADDR"); vaultAddr != "" {
		vaultToken := os.Getenv("VAULT_TOKEN")
		vaultPath  := getEnv("VAULT_KEY_PATH", "secret/data/auth/rsa-key")
		privateKey, err = authvault.LoadRSAKey(vaultAddr, vaultToken, vaultPath)
		if err != nil {
			log.Fatal("load RSA key from Vault", zap.Error(err))
		}
		log.Info("RSA key loaded from Vault", zap.String("path", vaultPath))
	} else {
		privateKey, err = rsa.GenerateKey(rand.Reader, 2048)
		if err != nil {
			log.Fatal("generate rsa key", zap.Error(err))
		}
		log.Warn("using ephemeral RSA key — set VAULT_ADDR + VAULT_TOKEN + VAULT_KEY_PATH for production")
	}

	// Wire dependencies
	userRepo     := postgres.NewUserRepo(dbPool)
	sessionStore := redisstore.New(rdb)
	tokenSigner  := authjwt.New(privateKey, &privateKey.PublicKey, "ultra-sync-auth")
	authUC       := usecase.New(userRepo, sessionStore, tokenSigner)
	handler      := httphandler.New(authUC, &privateKey.PublicKey)

	// HTTP server
	if env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}
	router := gin.New()
	router.Use(gin.Recovery())
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "auth"})
	})
	handler.Register(router)

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", getEnv("PORT", "8081")),
		Handler:      router,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Info("auth service starting", zap.String("addr", srv.Addr))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("listen", zap.Error(err))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("shutting down auth service...")
	shutCtx, shutCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutCancel()
	if err := srv.Shutdown(shutCtx); err != nil {
		log.Error("server shutdown", zap.Error(err))
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
