# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Ultra-Sync Super App** — a learning/portfolio project combining Logistics, Digital Wallet, and Real-time Chat into a production-grade Super App. Backend in Go, frontend in Flutter.

> **Status:** Project is in the documentation/planning phase. The `backend/` and `frontend/` directories are empty. Use `docs/TODO.md` to track what has been built.

---

## Planned Commands

### Backend (Go Microservices)

```bash
# Start all infrastructure (Postgres, Kafka, Redis, Vault, Jaeger, Prometheus)
docker compose up -d

# Run a specific service
cd backend/services/auth && go run ./cmd/...

# Run tests for a service
cd backend/services/auth && go test ./...

# Run a single test
go test ./internal/usecase/... -run TestFunctionName -v

# Generate Go code from Protobuf
cd backend/proto && protoc --go_out=. --go-grpc_out=. *.proto

# Lint (golangci-lint)
golangci-lint run ./...
```

### Frontend (Flutter)

```bash
# Get dependencies
flutter pub get

# Generate Dart code from Protobuf
protoc --dart_out=. *.proto

# Run on device/emulator
flutter run

# Run tests
flutter test

# Run a single test file
flutter test test/features/auth/auth_bloc_test.dart

# Generate code (freezed, json_serializable)
dart run build_runner build --delete-conflicting-outputs

# Lint
flutter analyze
```

---

## Architecture

### Backend: Hexagonal Architecture per Microservice

Each service under `backend/services/<name>/` follows this strict layering:

```
/cmd        → main.go: wires dependencies only, no business logic
/internal
  /domain   → Entities + Port Interfaces (pure Go, zero external imports)
  /usecase  → Business logic; calls only Port Interfaces, never SQL/Redis directly
  /adapter  → DB, gRPC, Redis, Kafka implementations of Port Interfaces
/test       → Integration tests
```

**Critical rules:**
- `domain` must never import from `adapter` or any infrastructure package.
- Services communicate only via gRPC — never by importing each other's `/internal`.
- Every IO function (DB, network) must accept `context.Context` as first argument.
- Wrap all errors: `fmt.Errorf("description: %w", err)`. Never discard errors with `_`.

### Frontend: Clean Architecture (Feature-first)

Each feature under `mobile/lib/features/<name>/` has three layers:

```
/data         → Remote/local data sources, Models (JSON ↔ Model mapping), Repository implementations
/domain       → Entities, Use Cases, Repository interfaces (no Flutter/data imports)
/presentation → BLoC, Pages, Widgets
```

**Critical rules:**
- Presentation talks only to Use Cases — never calls repositories or data sources directly.
- Domain layer must not import from `data` or `presentation`.
- JSON deserialization belongs in `data` Models, never in Domain Entities.
- All BLoC states must be immutable (`freezed` or `equatable`).
- No business logic inside `build()` methods or Widgets.
- Files must use `snake_case.dart`; classes use `PascalCase`.
- Keep files under 300 lines — extract widgets when exceeded.
- Heavy CPU work must run in a Dart `Isolate`.

### Inter-Service Communication

| Channel | Usage |
|---|---|
| gRPC + mTLS | Internal service-to-service calls |
| REST (Gin) | External API consumed by mobile |
| WebSocket | Real-time GPS tracking and chat |
| Apache Kafka | Async event streaming (order status, notifications) |

### Databases (one per service, no cross-service DB access)

| Service | DB | Notes |
|---|---|---|
| Auth | PostgreSQL | Sessions also in Redis |
| Logistics | PostgreSQL + PostGIS | GPS coords cached in Redis |
| Wallet | PostgreSQL | Optimistic locking via `version` column |

---

## API Contract Standards

All REST responses use this envelope — no exceptions:

```json
{
  "data": {},
  "meta": { "request_id": "uuid", "timestamp": "ISO8601" },
  "error": null
}
```

- Pagination: **cursor-based** (`after`, `before`, `limit`). Never use offset.
- Financial/mutation endpoints require `X-Idempotency-Key` header.
- Error codes follow the format `VAL-001`, `AUTH-002`, etc. with field-level `details`.

---

## Database Conventions

- Primary keys: `UUID v4` always.
- Timestamps: `TIMESTAMPTZ` always.
- Money: `DECIMAL(20, 4)`.
- Index every foreign key, every status/filter column, and use composite `(created_at, id)` for pagination.
- `ShipmentLogs` is partitioned by month.
- `Wallets.version` implements optimistic locking for concurrent transfers.
- `Transactions.idempotency_key` has a UNIQUE index.

---

## Security & Observability

- Secrets (DB creds, signing keys, API keys) go through **HashiCorp Vault** — never in `.env` files committed to git or hardcoded.
- Every Go service must instrument with **OpenTelemetry** and expose a `/health` endpoint.
- Use **uber-go/zap** or `slog` for structured JSON logging.
- Apply **Circuit Breaker** + **Exponential Backoff** for all inter-service calls.
- JWT uses RSA signing; services use mTLS for internal gRPC.

---

## Go Naming Conventions

- Package names: lowercase, no underscores (`authservice`, `walletrepo`).
- Initialisms uppercase: `userID` not `userId`, `httpURL` not `httpUrl`.
- Interface names end in `-er` when possible: `Reader`, `Storer`, `LocationWriter`.
- No `init()` for setup logic — use constructor injection.

---

## Key Documentation

| File | Purpose |
|---|---|
| `docs/TODO.md` | Master checklist — check here first for current task status |
| `docs/PHASES.md` | 6-week implementation timeline |
| `docs/SCHEMA.md` | Full DB schema for all three services |
| `docs/API_CONTRACTS.md` | REST endpoint specs and response examples |
| `docs/CONVENTIONS.md` | Full coding rules for Go and Flutter |
| `docs/PROJECT_STRUCTURE.md` | Folder layout with Do/Don't rules |
| `docs/ENTERPRISE_STANDARDS.md` | Security, observability, resilience standards |
