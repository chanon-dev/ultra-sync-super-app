# Local Development Runbook — Ultra-Sync Super App

> คู่มือการรันระบบในเครื่อง (Local) — เอกสารนี้เขียนทั้งภาษาไทยและอังกฤษควบคู่กัน

---

## สารบัญ / Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Infrastructure (Docker)](#2-infrastructure-docker)
3. [Backend Services (Go)](#3-backend-services-go)
4. [Frontend (Flutter)](#4-frontend-flutter)
5. [Service Integration Checklist](#5-service-integration-checklist)
6. [Load Testing (k6)](#6-load-testing-k6)
7. [Observability Dashboard](#7-observability-dashboard)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Prerequisites

### ติดตั้งเครื่องมือที่จำเป็น / Install Required Tools

| Tool | Installed | Required | Status | Install |
| --- | --- | --- | --- | --- |
| Docker | 29.1.3 | >= 24 | OK | — |
| Go | 1.26.2 | >= 1.22 | OK | — |
| Node.js | 22.16.0 | >= 20 | OK | — |
| Flutter | — | >= 3.22 | MISSING | see below |
| k6 | — | >= 0.51 | MISSING | `brew install k6` |
| protoc | — | >= 26 | optional | `brew install protobuf` |
| golangci-lint | — | >= 1.58 | optional | `brew install golangci-lint` |

### ติดตั้ง Flutter (macOS ARM) / Install Flutter on macOS ARM

```bash
brew install --cask flutter

# ตรวจสอบ / Verify
flutter --version
flutter doctor
```

### ติดตั้ง k6 / Install k6

```bash
brew install k6
k6 version
```

### ตรวจสอบการติดตั้งทั้งหมด / Verify All Installations

```bash
go version        # go1.26.2 darwin/arm64
docker --version  # Docker version 29.1.3
node --version    # v22.16.0
flutter --version # Flutter 3.x.x
k6 version        # k6 v0.51.x
```

---

## 2. Infrastructure (Docker)

### เริ่มต้น Infrastructure ทั้งหมด / Start All Infrastructure

Infrastructure ประกอบด้วย: PostgreSQL, Redis, Apache Kafka, HashiCorp Vault, Jaeger, Prometheus, Grafana

```bash
# จาก root ของโปรเจกต์ / From project root
docker compose up -d
```

### ตรวจสอบว่า Container ทำงานครบ / Verify All Containers Are Running

```bash
docker compose ps
```

ผลลัพธ์ที่ควรเห็น / Expected output — all services should show `running`:

```text
NAME                  STATUS
ultra-sync-postgres   running
ultra-sync-redis      running
ultra-sync-kafka      running
ultra-sync-vault      running
ultra-sync-jaeger     running
ultra-sync-prometheus running
ultra-sync-grafana    running
```

### Port ที่ใช้งาน / Exposed Ports

| Service | Port | Description |
| --- | --- | --- |
| PostgreSQL | `5432` | Primary database |
| Redis | `6379` | Cache & Session |
| Kafka | `9092` | Message Broker |
| Vault | `8200` | Secrets Management |
| Jaeger UI | `16686` | Distributed Tracing |
| Prometheus | `9090` | Metrics |
| Grafana | `3000` | Dashboard |

### หยุด Infrastructure / Stop Infrastructure

```bash
# หยุดแต่ไม่ลบ Volume (แนะนำระหว่าง Dev)
docker compose stop

# หยุดและลบ Volume ทั้งหมด (reset สมบูรณ์)
docker compose down -v
```

---

## 3. Backend Services (Go)

### 3.1 Auth Service

**รันก่อน** เพราะ Service อื่นต้องการ Token จาก Auth
**Run first** — other services depend on tokens issued by Auth.

```bash
cd backend/services/auth
go mod tidy
# Auth ใช้ HTTP/Gin ไม่ต้องการ proto generation
go run ./cmd/...
```

ตรวจสอบ / Verify:

```bash
curl http://localhost:8081/health
# {"status":"ok","service":"auth"}
```

---

### 3.2 Wallet Service

```bash
cd backend/services/wallet
go mod tidy
go run ./cmd/...
```

ตรวจสอบ / Verify:

```bash
curl http://localhost:8082/health
# {"status":"ok","service":"wallet"}
```

---

### 3.3 Logistics Service

```bash
cd backend/services/logistics
go mod tidy
go run ./cmd/...
```

ตรวจสอบ / Verify:

```bash
curl http://localhost:8083/health
# {"status":"ok","service":"logistics"}
```

---

### 3.4 API Gateway

**รันหลังสุด** — Gateway เป็นจุดรับ Request จาก Mobile
**Run last** — Gateway is the single entry point for mobile.

```bash
cd backend/api-gateway
go mod tidy
go run ./cmd/...
```

ตรวจสอบ / Verify:

```bash
curl http://localhost:8080/health
# {"status":"ok","service":"api-gateway"}
```

---

### 3.5 รัน Backend ทุก Service พร้อมกัน / Run All Backend Services at Once

เปิด 4 Terminal แยกกัน / Open 4 separate terminals:

```bash
# Terminal 1
cd backend/services/auth && go run ./cmd/...

# Terminal 2
cd backend/services/wallet && go run ./cmd/...

# Terminal 3
cd backend/services/logistics && go run ./cmd/...

# Terminal 4
cd backend/api-gateway && go run ./cmd/...
```

---

### 3.6 รัน Tests (Backend) / Run Backend Tests

```bash
# ทดสอบ Service เดียว
cd backend/services/auth
go test ./... -v

# ทดสอบ function เดียว
go test ./internal/usecase/... -run TestRegisterUser -v

# Lint
golangci-lint run ./...
```

---

## 4. Frontend (Flutter)

### 4.1 ตั้งค่า Environment / Configure Environment

แก้ไข `BASE_URL` ใน `mobile/lib/core/config/app_config.dart`:

```dart
const String baseUrl = 'http://localhost:8080';
```

> **Android Emulator:** ใช้ `10.0.2.2` แทน `localhost`
>
> **iOS Simulator / Physical device (same network):** ใช้ IP เครื่อง เช่น `192.168.1.x`

---

### 4.2 ติดตั้ง Dependencies / Install Dependencies

```bash
cd mobile
flutter pub get
```

> **ถ้า dependency conflict:** รันคำสั่งนี้แทน — จะอัปเกรดทุก package ข้าม major version และแก้ `pubspec.yaml` ให้อัตโนมัติ
>
> ```bash
> flutter pub upgrade --major-versions
> ```

---

### 4.3 Generate Code / Code Generation

```bash
# Freezed + json_serializable
dart run build_runner build --delete-conflicting-outputs
```

---

### 4.4 รัน App / Run App

```bash
# แสดง Device ที่เชื่อมต่ออยู่
flutter devices

# รันบน iOS Simulator
flutter run -d iPhone

# รันบน Android
flutter run -d <device_id>

# รันบน Chrome (Web)
flutter run -d chrome
```

---

### 4.5 รัน Tests (Frontend) / Run Frontend Tests

```bash
cd mobile
flutter test
flutter test test/features/auth/auth_bloc_test.dart
flutter analyze
```

---

## 5. Service Integration Checklist

ตรวจสอบตามลำดับก่อน Test ด้วย Flutter / Check in order before testing with Flutter:

```text
[ ] docker compose ps          → all containers "running"
[ ] curl localhost:8081/health → Auth OK
[ ] curl localhost:8082/health → Wallet OK
[ ] curl localhost:8083/health → Logistics OK
[ ] curl localhost:8080/health → API Gateway OK
[ ] flutter devices            → device/simulator visible
[ ] flutter run                → app launches without error
```

### ทดสอบ Flow พื้นฐาน / Smoke Test Core Flows

```bash
# 1. Register
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"dev@test.com","password":"Dev@1234","role":"user"}'

# 2. Login — คัดลอก access_token จาก response
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"dev@test.com","password":"Dev@1234"}'

# 3. Wallet Balance
curl http://localhost:8080/api/v1/wallet/balance \
  -H "Authorization: Bearer <access_token>"

# 4. Create Shipment
curl -X POST http://localhost:8080/api/v1/shipments \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"pickup_lat":13.75,"pickup_lng":100.5,"dropoff_lat":13.8,"dropoff_lng":100.55}'
```

---

## 6. Load Testing (k6)

### Build TypeScript tests ก่อน / Build TypeScript Tests First

```bash
cd tests/k6
npm install    # ครั้งแรกเท่านั้น / first time only
npm run build  # compile TS → dist/*.js
```

### รัน Test แต่ละ Service / Run Tests per Service

```bash
k6 run dist/auth.js
k6 run dist/wallet.js
k6 run dist/logistics.js

# กำหนด URL เอง
k6 run -e BASE_URL=http://localhost:8080 dist/auth.js
```

### ดู Report สรุป / Read Summary Report

k6 แสดง Threshold summary หลัง Test เสร็จ:

```text
✓ http_req_failed.....: 0.00%
✓ http_req_duration...: avg=42ms p(99)=310ms
✓ error_rate..........: 0.00%
```

---

## 7. Observability Dashboard

| Tool | URL | Login |
| --- | --- | --- |
| Jaeger (Tracing) | <http://localhost:16686> | — |
| Prometheus | <http://localhost:9090> | — |
| Grafana | <http://localhost:3000> | admin / admin |

---

## 8. Troubleshooting

### Port ชนกัน / Port Already in Use

```bash
lsof -i :8080
kill -9 <PID>
```

### Kafka ไม่ขึ้น / Kafka Not Starting

```bash
docker compose logs kafka
docker compose down -v && docker compose up -d
```

### Flutter ไม่เชื่อมต่อ Backend / Flutter Cannot Connect to Backend

1. ตรวจสอบ `BASE_URL` ใน `app_config.dart`
2. Android Emulator ต้องใช้ `10.0.2.2` ไม่ใช่ `localhost`
3. ตรวจสอบว่า API Gateway รันอยู่ที่ port 8080

### Vault Sealed / Vault ถูก Seal

```bash
docker exec -it ultra-sync-vault vault operator unseal <unseal_key>
```
