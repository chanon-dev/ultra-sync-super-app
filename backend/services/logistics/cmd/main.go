package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/joho/godotenv"

	"github.com/chanon/ultra-sync/pkg/logger"
	"github.com/chanon/ultra-sync/pkg/tracing"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
	"github.com/chanon/ultra-sync/services/logistics/internal/adapter/events"
	"github.com/chanon/ultra-sync/services/logistics/internal/adapter/httphandler"
	"github.com/chanon/ultra-sync/services/logistics/internal/adapter/notifier"
	"github.com/chanon/ultra-sync/services/logistics/internal/adapter/postgres"
	"github.com/chanon/ultra-sync/services/logistics/internal/adapter/rediscache"
	"github.com/chanon/ultra-sync/services/logistics/internal/adapter/walletclient"
	"github.com/chanon/ultra-sync/services/logistics/internal/domain/port"
	"github.com/chanon/ultra-sync/services/logistics/internal/usecase"
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

	shutdownTracing, err := tracing.Init(ctx, "logistics-service", getEnv("OTLP_ENDPOINT", "localhost:4318"))
	if err != nil {
		log.Warn("tracing init failed", zap.Error(err))
	} else {
		defer shutdownTracing(ctx) //nolint:errcheck
	}

	dbPool, err := pgxpool.New(ctx, getEnv("LOGISTICS_DB_DSN",
		"postgres://logisticsuser:logisticspass@localhost:5433/logisticsdb?sslmode=disable"))
	if err != nil {
		log.Fatal("connect to logisticsdb", zap.Error(err))
	}
	defer dbPool.Close()

	if err := dbPool.Ping(ctx); err != nil {
		log.Fatal("ping logisticsdb", zap.Error(err))
	}

	redisOpts, err := redis.ParseURL(getEnv("REDIS_URL", "redis://:redispass@localhost:6379/1"))
	if err != nil {
		log.Fatal("parse redis url", zap.Error(err))
	}
	rdb := redis.NewClient(redisOpts)
	defer rdb.Close()

	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatal("ping redis", zap.Error(err))
	}

	// Wire adapters.
	shipmentRepo := postgres.NewShipmentRepo(dbPool)
	logRepo      := postgres.NewShipmentLogRepo(dbPool)
	locCache     := rediscache.New(rdb)

	var publisher port.EventPublisher
	if brokerList := getEnv("KAFKA_BROKERS", ""); brokerList != "" {
		kp, err := events.NewKafka(strings.Split(brokerList, ","))
		if err != nil {
			log.Fatal("connect to kafka", zap.Error(err))
		}
		defer kp.Close() //nolint:errcheck
		publisher = kp
		log.Info("using kafka publisher", zap.String("brokers", brokerList))
	} else {
		publisher = events.NewNoop()
		log.Warn("using noop event publisher — set KAFKA_BROKERS for production")
	}

	// Saga: wallet client charges sender when shipment is delivered.
	// Set WALLET_SERVICE_URL (e.g. http://wallet-service:8083) in production.
	walletURL := getEnv("WALLET_SERVICE_URL", "")
	var walletSaga port.WalletClient
	if walletURL != "" {
		walletSaga = walletclient.New(walletURL)
		log.Info("saga wallet client enabled", zap.String("url", walletURL))
	} else {
		log.Warn("WALLET_SERVICE_URL not set — delivery saga payment disabled in dev")
	}

	// Wire use case.
	pushNotifier := notifier.New(log)
	driverRepo := postgres.NewDriverRepo(dbPool)
	driverUC := usecase.NewDriverUseCase(driverRepo)
	shipmentUC := usecase.New(shipmentRepo, logRepo, logRepo, locCache, publisher, walletSaga, pushNotifier)

	// Wire HTTP handler.
	handler := httphandler.New(shipmentUC, driverUC)

	if env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}
	router := gin.New()
	router.Use(otelgin.Middleware("logistics-service"))
	router.Use(gin.Recovery())
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "logistics"})
	})
	handler.Register(router)

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", getEnv("PORT", "8082")),
		Handler:      router,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 60 * time.Second, // longer for SSE streams
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		log.Info("logistics service starting", zap.String("addr", srv.Addr))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("listen", zap.Error(err))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("shutting down logistics service...")
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
