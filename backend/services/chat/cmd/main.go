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
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
	"go.uber.org/zap"

	"github.com/chanon/ultra-sync/pkg/logger"
	"github.com/chanon/ultra-sync/pkg/tracing"
	"github.com/chanon/ultra-sync/services/chat/internal/adapter/filestorage"
	"github.com/chanon/ultra-sync/services/chat/internal/adapter/httphandler"
	"github.com/chanon/ultra-sync/services/chat/internal/adapter/kafkapub"
	"github.com/chanon/ultra-sync/services/chat/internal/adapter/postgres"
	"github.com/chanon/ultra-sync/services/chat/internal/adapter/redispubsub"
	"github.com/chanon/ultra-sync/services/chat/internal/usecase"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

func main() {
	_ = godotenv.Load()

	env := getEnv("APP_ENV", "development")

	log := logger.Must(env)
	defer log.Sync() //nolint:errcheck

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 1. Tracing
	shutdownTracing, err := tracing.Init(ctx, "chat-service", getEnv("OTLP_ENDPOINT", "localhost:4318"))
	if err != nil {
		log.Warn("tracing init failed, continuing without tracing", zap.Error(err))
	} else {
		defer shutdownTracing(ctx) //nolint:errcheck
	}

	// 2. Database (Isolated ChatDB)
	dbPool, err := pgxpool.New(ctx, getEnv("CHAT_DB_DSN",
		"postgres://chatuser:chatpass@localhost:5435/chatdb?sslmode=disable"))
	if err != nil {
		log.Fatal("failed to connect to chatdb", zap.Error(err))
	}
	defer dbPool.Close()

	if err := dbPool.Ping(ctx); err != nil {
		log.Fatal("failed to ping chatdb", zap.Error(err))
	}

	// 3. Redis (for Pub/Sub and caching)
	redisOpts, err := redis.ParseURL(getEnv("REDIS_URL", "redis://:redispass@localhost:6379/0"))
	if err != nil {
		log.Fatal("failed to parse redis url", zap.Error(err))
	}
	rdb := redis.NewClient(redisOpts)
	defer rdb.Close()

	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatal("failed to ping redis", zap.Error(err))
	}

	// 4. Kafka Brokers Parsing
	kafkaBrokersStr := os.Getenv("KAFKA_BROKERS")
	var kafkaBrokers []string
	if kafkaBrokersStr != "" {
		kafkaBrokers = strings.Split(kafkaBrokersStr, ",")
	}

	// 5. Wire adapters & dependencies
	messageRepo := postgres.NewMessageRepo(dbPool)
	roomRepo := postgres.NewRoomRepo(dbPool)
	redisBroker := redispubsub.New(rdb)

	kafkaPublisher, err := kafkapub.NewPublisher(kafkaBrokers, log)
	if err != nil {
		log.Fatal("failed to initialize kafka publisher", zap.Error(err))
	}
	defer kafkaPublisher.Close() //nolint:errcheck

	uploadDir := getEnv("UPLOAD_DIR", "/tmp/chat-uploads")
	uploadBaseURL := getEnv("UPLOAD_BASE_URL", "http://localhost:8084/uploads")
	fileStore, err := filestorage.New(uploadDir, uploadBaseURL)
	if err != nil {
		log.Fatal("failed to init file storage", zap.Error(err))
	}

	chatUC := usecase.New(messageRepo, redisBroker, kafkaPublisher, roomRepo, fileStore)
	handler := httphandler.New(chatUC, log)

	// 6. Start Kafka Asynchronous Background Database Writer
	kafkapub.StartBackgroundWriter(ctx, kafkaBrokers, chatUC.SaveMessage, log)

	// 7. Gin Server setup
	if env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}
	router := gin.New()
	router.Use(otelgin.Middleware("chat-service"))
	router.Use(gin.Recovery())

	// Add basic cors/headers for local direct testing
	router.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Headers", "Content-Type,Authorization,X-User-ID,X-User-Role")
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	})

	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "chat"})
	})

	handler.Register(router)

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", getEnv("PORT", "8084")),
		Handler:      router,
		ReadTimeout:  60 * time.Second, // higher timeout to keep websocket idle streams active
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		log.Info("chat service starting", zap.String("addr", srv.Addr))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("listen", zap.Error(err))
		}
	}()

	// Support Graceful Shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("shutting down chat service...")
	cancel() // Cancels consumer context and child loops

	shutCtx, shutCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutCancel()

	if err := srv.Shutdown(shutCtx); err != nil {
		log.Error("server shutdown failed", zap.Error(err))
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
