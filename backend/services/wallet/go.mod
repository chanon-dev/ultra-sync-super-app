module github.com/chanon/ultra-sync/services/wallet

go 1.22

require (
	github.com/chanon/ultra-sync/pkg v0.0.0
	github.com/gin-gonic/gin v1.10.0
	github.com/google/uuid v1.6.0
	github.com/jackc/pgx/v5 v5.6.0
	github.com/joho/godotenv v1.5.1
	github.com/shopspring/decimal v1.4.0
	go.opentelemetry.io/otel v1.27.0
	go.opentelemetry.io/otel/trace v1.27.0
	go.uber.org/zap v1.27.0
	google.golang.org/grpc v1.64.0
	google.golang.org/protobuf v1.34.1
)

replace github.com/chanon/ultra-sync/pkg => ../../pkg
