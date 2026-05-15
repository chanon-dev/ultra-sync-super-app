module github.com/chanon/ultra-sync/services/auth

go 1.22

require (
	github.com/chanon/ultra-sync/pkg v0.0.0
	github.com/gin-gonic/gin v1.10.0
	github.com/golang-jwt/jwt/v5 v5.2.1
	github.com/google/uuid v1.6.0
	github.com/jackc/pgx/v5 v5.6.0
	github.com/redis/go-redis/v9 v9.5.3
	go.opentelemetry.io/otel v1.27.0
	go.opentelemetry.io/otel/trace v1.27.0
	go.uber.org/zap v1.27.0
	golang.org/x/crypto v0.24.0
	google.golang.org/grpc v1.64.0
	google.golang.org/protobuf v1.34.1
)
