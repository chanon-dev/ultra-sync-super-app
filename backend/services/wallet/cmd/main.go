package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joho/godotenv"

	"github.com/chanon/ultra-sync/pkg/logger"
	"github.com/chanon/ultra-sync/pkg/tracing"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
	"github.com/chanon/ultra-sync/services/wallet/internal/adapter/httphandler"
	"github.com/chanon/ultra-sync/services/wallet/internal/adapter/notifier"
	"github.com/chanon/ultra-sync/services/wallet/internal/adapter/postgres"
	"github.com/chanon/ultra-sync/services/wallet/internal/usecase"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

func main() {
	_ = godotenv.Load()

	env := getEnv("APP_ENV", "development")
	log := logger.Must(env)
	defer log.Sync() //nolint:errcheck

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	shutdownTracing, err := tracing.Init(ctx, "wallet-service", getEnv("OTLP_ENDPOINT", "localhost:4318"))
	if err != nil {
		log.Warn("tracing init failed", zap.Error(err))
	} else {
		defer shutdownTracing(ctx) //nolint:errcheck
	}

	dbPool, err := pgxpool.New(ctx, getEnv("WALLET_DB_DSN",
		"postgres://walletuser:walletpass@localhost:5434/walletdb?sslmode=disable"))
	if err != nil {
		log.Fatal("connect to walletdb", zap.Error(err))
	}
	defer dbPool.Close()

	if err := dbPool.Ping(ctx); err != nil {
		log.Fatal("ping walletdb", zap.Error(err))
	}

	walletRepo := postgres.NewWalletRepo(dbPool)
	txRepo := postgres.NewTransactionRepo(dbPool)
	uc := usecase.New(walletRepo, txRepo).WithNotifier(notifier.New(log))
	handler := httphandler.New(uc, log)

	if env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}
	router := gin.New()
	router.Use(otelgin.Middleware("wallet-service"))
	router.Use(gin.Recovery())
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "wallet"})
	})
	handler.Register(router)

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", getEnv("PORT", "8083")),
		Handler:      router,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Info("wallet service starting", zap.String("addr", srv.Addr))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("listen", zap.Error(err))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("shutting down wallet service...")
	shutCtx, shutCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutCancel()
	srv.Shutdown(shutCtx) //nolint:errcheck
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
