# Ultra-Sync Super App

A production-grade **Super App** combining Logistics, Digital Wallet, and Real-time tracking.
Backend in **Go** (Hexagonal Architecture), frontend in **Flutter** (Clean Architecture + BLoC).

> **Status:** All 5 phases complete — see [docs/TODO.md](./docs/TODO.md).

---

## Architecture Overview

```text
ultra-sync/
├── backend/               # Go Microservices (Go Workspaces)
│   ├── api-gateway/       # Reverse proxy, JWT validation, rate limiting
│   ├── services/
│   │   ├── auth/          # Register, Login, Token Rotation, Vault RSA keys
│   │   ├── logistics/     # Orders CRUD, Driver dispatch, GPS tracking, Kafka events
│   │   └── wallet/        # Balance, Top-up, Saga pay, Audit log, QR
│   ├── proto/             # Protobuf definitions (buf.yaml)
│   ├── configs/           # Prometheus, Grafana provisioning
│   └── docker-compose.yaml
├── frontend/              # Flutter app
│   ├── lib/
│   │   ├── core/          # DI, router, services (LocationService)
│   │   └── features/      # auth / logistics / wallet — each with data/domain/presentation
│   ├── test/              # Unit + BLoC tests
│   └── integration_test/  # Patrol E2E tests
├── k8s/                   # Kubernetes manifests
├── helm/                  # Helm chart (ultra-sync/)
└── tests/k6/              # Load-test scripts
```

---

## Prerequisites

| Tool               | Version | Purpose                    |
| ------------------ | ------- | -------------------------- |
| Go                 | ≥ 1.22  | Backend services           |
| Docker + Compose   | v2+     | Infrastructure             |
| Flutter            | ≥ 3.19  | Mobile app                 |
| `buf` CLI          | latest  | Protobuf code generation   |
| `golangci-lint`    | latest  | Go linting                 |
| `patrol` CLI       | latest  | Flutter E2E tests          |

---

## Backend

### 1. Start Infrastructure

```bash
cd backend
docker compose up -d
```

Starts: PostgreSQL ×3, Redis, Kafka + Zookeeper, HashiCorp Vault (dev mode), Jaeger, Prometheus, Grafana.

| Service           | URL                                                      |
| ----------------- | -------------------------------------------------------- |
| API Gateway       | <http://localhost:8080>                                  |
| Auth Service      | <http://localhost:8081>                                  |
| Logistics Service | <http://localhost:8082>                                  |
| Wallet Service    | <http://localhost:8083>                                  |
| Vault UI          | <http://localhost:8200> (token: `ultra-sync-dev-token`)  |
| Jaeger UI         | <http://localhost:16686>                                 |
| Prometheus        | <http://localhost:9090>                                  |
| Grafana           | <http://localhost:3000> (admin / admin)                  |

### 2. Generate Protobuf Stubs

```bash
cd backend
make proto        # requires buf CLI
```

Outputs Go stubs to `backend/proto/gen/go/` and Dart stubs to `backend/proto/gen/dart/`.

### 3. Configure Environment

Each service reads its config from a `.env` file at startup (via `godotenv`).
Copy the template and edit as needed — the defaults work out-of-the-box with `docker compose up -d`.

```bash
cp backend/services/auth/.env     # already provided, edit if needed
cp backend/services/logistics/.env
cp backend/services/wallet/.env
cp backend/api-gateway/.env
```

Or generate from the committed templates:

```bash
for svc in services/auth services/logistics services/wallet api-gateway; do
  cp backend/$svc/env.example backend/$svc/.env
done
```

**Per-service `.env` keys:**

`services/auth/.env`

```env
APP_ENV=development
PORT=8081
AUTH_DB_DSN=postgres://authuser:authpass@localhost:5432/authdb?sslmode=disable
REDIS_URL=redis://:redispass@localhost:6379/0
VAULT_ADDR=                          # blank → ephemeral RSA key (dev only)
VAULT_TOKEN=
VAULT_KEY_PATH=secret/data/auth/rsa-key
OTLP_ENDPOINT=localhost:4318
```

`services/logistics/.env`

```env
APP_ENV=development
PORT=8082
LOGISTICS_DB_DSN=postgres://logisticsuser:logisticspass@localhost:5433/logisticsdb?sslmode=disable
REDIS_URL=redis://:redispass@localhost:6379/1
KAFKA_BROKERS=                       # blank → noop publisher (dev only)
WALLET_SERVICE_URL=                  # blank → saga payment skipped (dev only)
OTLP_ENDPOINT=localhost:4318
```

`services/wallet/.env`

```env
APP_ENV=development
PORT=8083
WALLET_DB_DSN=postgres://walletuser:walletpass@localhost:5434/walletdb?sslmode=disable
OTLP_ENDPOINT=localhost:4318
```

`api-gateway/.env`

```env
APP_ENV=development
PORT=8080
AUTH_SERVICE_URL=http://localhost:8081
LOGISTICS_SERVICE_URL=http://localhost:8082
WALLET_SERVICE_URL=http://localhost:8083
OTLP_ENDPOINT=localhost:4318
```

### 4. Run Services

Run each service in a separate terminal — config is loaded from `.env` automatically:

```bash
cd backend/services/auth && go run ./cmd/...
cd backend/services/logistics && go run ./cmd/...
cd backend/services/wallet && go run ./cmd/...
cd backend/api-gateway && go run ./cmd/...
```

**Optional dev overrides** — env vars set in the shell override `.env` values:

- Set `VAULT_ADDR` + `VAULT_TOKEN` → auth loads RSA key from Vault instead of generating one.
- Set `KAFKA_BROKERS` → logistics publishes events to Kafka.
- Set `WALLET_SERVICE_URL` (in logistics) → enables delivery saga payment.

### 4. Tests & Linting

```bash
cd backend

make test     # go test ./... for all 3 services
make lint     # golangci-lint for all services + gateway
make tidy     # go mod tidy for every module
```

Run a single test:

```bash
cd backend/services/auth
go test ./internal/usecase/... -run TestLoginUseCase -v
```

---

## Frontend (Flutter)

### 1. Install Dependencies

```bash
cd frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 2. Configure Environment

The app reads config from `frontend/.env` at runtime (via `flutter_dotenv`, bundled as an asset).
Copy the template and edit as needed:

```bash
cp frontend/env.example frontend/.env
```

`frontend/.env`

```env
API_BASE_URL=http://localhost:8080

# Optional — leave blank to show coordinate placeholder on the tracking screen.
MAPS_API_KEY=
```

`.env` is gitignored. `env.example` is the committed template.

> **Note on `API_BASE_URL` for device testing:**
> If running on a physical Android device, replace `localhost` with your machine's local IP
> (e.g. `http://192.168.1.x:8080`). iOS Simulator can use `localhost` directly.

### 3. Run on Device / Emulator

```bash
flutter run
```

No `--dart-define` flags needed — values come from `.env`.

For CI / production builds where no `.env` file is bundled, pass flags directly:

```bash
flutter build apk \
  --dart-define=API_BASE_URL=https://api.ultra-sync.io \
  --dart-define=MAPS_API_KEY=<your_key>
```

`_mapsApiKey` in the tracking screen checks dotenv first, then falls back to `--dart-define`, so both paths work.

### 3. Unit & BLoC Tests

```bash
flutter test                                          # all tests
flutter test test/features/auth/auth_bloc_test.dart  # single file
```

### 4. E2E Tests (Patrol)

Requires a connected physical device or running emulator:

```bash
# Install Patrol CLI
dart pub global activate patrol_cli

# Run all integration tests
patrol test

# Run a specific suite
patrol test integration_test/auth_test.dart
patrol test integration_test/wallet_test.dart
patrol test integration_test/logistics_test.dart
```

### 5. Lint

```bash
flutter analyze
```

---

## Production Configuration

### Backend Environment Variables

| Variable             | Service         | Description                                               |
| -------------------- | --------------- | --------------------------------------------------------- |
| `VAULT_ADDR`         | auth            | Vault server URL                                          |
| `VAULT_TOKEN`        | auth            | Vault access token                                        |
| `VAULT_KEY_PATH`     | auth            | KV v2 path to RSA key (`secret/data/auth/rsa-key`)        |
| `KAFKA_BROKERS`      | logistics       | Comma-separated broker list (e.g. `kafka:9092`)           |
| `WALLET_SERVICE_URL` | logistics       | Internal URL of wallet service for delivery saga          |
| `DATABASE_URL`       | all             | PostgreSQL connection string                              |
| `REDIS_ADDR`         | auth, logistics | Redis address                                             |

### Flutter Build Flags

| Flag                              | Description                                 |
| --------------------------------- | ------------------------------------------- |
| `--dart-define=MAPS_API_KEY=<key>`| Enable live Google Maps on tracking screen  |

### Kubernetes / Helm

```bash
# Apply manifests directly
kubectl apply -f k8s/

# Deploy with Helm
helm upgrade --install ultra-sync helm/ultra-sync/ \
  --set global.imageTag=latest \
  --namespace ultra-sync --create-namespace
```

---

## Load Testing (k6)

```bash
k6 run tests/k6/auth.js
k6 run tests/k6/wallet.js
k6 run tests/k6/logistics.js
```

---

## Documentation

| File                                                               | Purpose                              |
| ------------------------------------------------------------------ | ------------------------------------ |
| [docs/TODO.md](./docs/TODO.md)                                     | Master checklist — phase completion  |
| [docs/PHASES.md](./docs/PHASES.md)                                 | 6-week implementation timeline       |
| [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)                     | System architecture diagram          |
| [docs/SCHEMA.md](./docs/SCHEMA.md)                                 | Full database schema                 |
| [docs/API_CONTRACTS.md](./docs/API_CONTRACTS.md)                   | REST endpoint specifications         |
| [docs/CONVENTIONS.md](./docs/CONVENTIONS.md)                       | Go and Flutter coding conventions    |
| [docs/ENTERPRISE_STANDARDS.md](./docs/ENTERPRISE_STANDARDS.md)     | Security and observability standards |
| [docs/TECH_STACK.md](./docs/TECH_STACK.md)                         | Full technology stack                |
