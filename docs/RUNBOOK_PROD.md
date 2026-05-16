# Production Deployment Runbook — Ultra-Sync Super App
# คู่มือการ Deploy ขึ้น Production

> **ภาษา / Language:** เอกสารนี้เขียนทั้งภาษาไทยและอังกฤษควบคู่กัน
> This document is written in both Thai and English side by side.

---

## สารบัญ / Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Secrets Management (Vault)](#2-secrets-management-vault)
3. [Build & Push Docker Images](#3-build--push-docker-images)
4. [Deploy to Kubernetes (Helm)](#4-deploy-to-kubernetes-helm)
5. [Frontend (Flutter) — Release Build](#5-frontend-flutter--release-build)
6. [Service Integration Checklist](#6-service-integration-checklist)
7. [Load Testing Against Production](#7-load-testing-against-production)
8. [Observability & Monitoring](#8-observability--monitoring)
9. [Rollback Procedure](#9-rollback-procedure)

---

## 1. Prerequisites

### เครื่องมือที่ต้องมี / Required Tools

| Tool | Version | Install |
|------|---------|---------|
| kubectl | ≥ 1.29 | `brew install kubectl` |
| helm | ≥ 3.14 | `brew install helm` |
| Docker | ≥ 24 | https://docs.docker.com/get-docker/ |
| vault CLI | ≥ 1.16 | `brew install vault` |
| k6 | ≥ 0.51 | `brew install k6` |
| Node.js | ≥ 20 | `brew install node` |
| Flutter | ≥ 3.22 | https://docs.flutter.dev/get-started/install |

### ตรวจสอบ Kubernetes Context / Verify Kubernetes Context

> **คำเตือน / Warning:** ตรวจสอบให้แน่ใจว่า context ชี้ไปที่ Cluster Production ที่ถูกต้อง

```bash
# ดู Context ปัจจุบัน / Show current context
kubectl config current-context

# เปลี่ยน Context (ถ้าจำเป็น) / Switch context (if needed)
kubectl config use-context ultra-sync-prod

# ตรวจสอบ Node ใน Cluster / Verify cluster nodes
kubectl get nodes
```

---

## 2. Secrets Management (Vault)

ห้าม hardcode ข้อมูลลับใน `.env` หรือโค้ดเด็ดขาด — ทุกอย่างต้องผ่าน HashiCorp Vault
Never hardcode secrets in `.env` or source code — all secrets must go through HashiCorp Vault.

### 2.1 Login เข้า Vault / Authenticate to Vault

```bash
export VAULT_ADDR=https://vault.your-domain.com

# ใช้ Token (CI/CD) หรือ OIDC (developer)
vault login -method=token
# หรือ / or
vault login -method=oidc
```

### 2.2 เขียน Secrets แต่ละ Service / Write Secrets per Service

```bash
# Auth Service
vault kv put secret/ultra-sync/auth \
  db_dsn="postgres://user:pass@postgres:5432/auth_db?sslmode=require" \
  jwt_private_key="@/path/to/rsa_private.pem" \
  jwt_public_key="@/path/to/rsa_public.pem" \
  redis_url="redis://:password@redis:6379/0"

# Wallet Service
vault kv put secret/ultra-sync/wallet \
  db_dsn="postgres://user:pass@postgres:5432/wallet_db?sslmode=require" \
  kafka_brokers="kafka:9092" \
  kafka_sasl_username="wallet-svc" \
  kafka_sasl_password="<kafka-password>"

# Logistics Service
vault kv put secret/ultra-sync/logistics \
  db_dsn="postgres://user:pass@postgres:5432/logistics_db?sslmode=require" \
  redis_url="redis://:password@redis:6379/1" \
  kafka_brokers="kafka:9092"
```

### 2.3 ตรวจสอบ Secrets / Verify Secrets

```bash
vault kv get secret/ultra-sync/auth
vault kv get secret/ultra-sync/wallet
vault kv get secret/ultra-sync/logistics
```

---

## 3. Build & Push Docker Images

### 3.1 ตั้งค่าตัวแปร / Set Variables

```bash
export REGISTRY=registry.your-domain.com/ultra-sync
export VERSION=$(git rev-parse --short HEAD)  # เช่น a1b2c3d
```

### 3.2 Build & Push แต่ละ Service / Build & Push Each Service

```bash
# Auth Service
docker build \
  -f backend/services/auth/Dockerfile \
  -t ${REGISTRY}/auth:${VERSION} \
  -t ${REGISTRY}/auth:latest \
  backend/services/auth

docker push ${REGISTRY}/auth:${VERSION}
docker push ${REGISTRY}/auth:latest

# Wallet Service
docker build \
  -f backend/services/wallet/Dockerfile \
  -t ${REGISTRY}/wallet:${VERSION} \
  -t ${REGISTRY}/wallet:latest \
  backend/services/wallet

docker push ${REGISTRY}/wallet:${VERSION}
docker push ${REGISTRY}/wallet:latest

# Logistics Service
docker build \
  -f backend/services/logistics/Dockerfile \
  -t ${REGISTRY}/logistics:${VERSION} \
  -t ${REGISTRY}/logistics:latest \
  backend/services/logistics

docker push ${REGISTRY}/logistics:${VERSION}
docker push ${REGISTRY}/logistics:latest

# API Gateway
docker build \
  -f backend/api-gateway/Dockerfile \
  -t ${REGISTRY}/api-gateway:${VERSION} \
  -t ${REGISTRY}/api-gateway:latest \
  backend/api-gateway

docker push ${REGISTRY}/api-gateway:${VERSION}
docker push ${REGISTRY}/api-gateway:latest
```

### 3.3 ตรวจสอบ Image ที่ Push / Verify Pushed Images

```bash
docker manifest inspect ${REGISTRY}/auth:${VERSION}
```

---

## 4. Deploy to Kubernetes (Helm)

Helm charts อยู่ที่ `helm/` — แต่ละ Service มี chart แยก

### 4.1 สร้าง Namespace (ครั้งแรก) / Create Namespace (First Time Only)

```bash
kubectl create namespace ultra-sync-prod
```

### 4.2 Deploy Infrastructure (ถ้าใช้ Helm สำหรับ Infra) / Deploy Infrastructure

```bash
# PostgreSQL
helm upgrade --install postgres bitnami/postgresql \
  --namespace ultra-sync-prod \
  --values helm/infra/postgres-values.yaml

# Redis
helm upgrade --install redis bitnami/redis \
  --namespace ultra-sync-prod \
  --values helm/infra/redis-values.yaml

# Kafka
helm upgrade --install kafka bitnami/kafka \
  --namespace ultra-sync-prod \
  --values helm/infra/kafka-values.yaml
```

### 4.3 Deploy Backend Services / Deploy Backend Services

**ลำดับสำคัญ:** Auth → Wallet → Logistics → API Gateway
**Order matters:** Auth → Wallet → Logistics → API Gateway

```bash
# Auth Service
helm upgrade --install auth ./helm/services/auth \
  --namespace ultra-sync-prod \
  --set image.tag=${VERSION} \
  --set vault.addr=https://vault.your-domain.com \
  --wait

# Wallet Service
helm upgrade --install wallet ./helm/services/wallet \
  --namespace ultra-sync-prod \
  --set image.tag=${VERSION} \
  --set vault.addr=https://vault.your-domain.com \
  --wait

# Logistics Service
helm upgrade --install logistics ./helm/services/logistics \
  --namespace ultra-sync-prod \
  --set image.tag=${VERSION} \
  --set vault.addr=https://vault.your-domain.com \
  --wait

# API Gateway
helm upgrade --install api-gateway ./helm/services/api-gateway \
  --namespace ultra-sync-prod \
  --set image.tag=${VERSION} \
  --wait
```

### 4.4 ตรวจสอบ Deployment / Verify Deployments

```bash
# ดูสถานะ Pod ทั้งหมด / Check all pod statuses
kubectl get pods -n ultra-sync-prod

# ดู Log ของ Pod / View pod logs
kubectl logs -n ultra-sync-prod -l app=auth --tail=50
kubectl logs -n ultra-sync-prod -l app=wallet --tail=50
kubectl logs -n ultra-sync-prod -l app=logistics --tail=50

# ตรวจสอบ Health endpoints / Check health endpoints
kubectl port-forward -n ultra-sync-prod svc/auth 8081:8081 &
curl http://localhost:8081/health
```

### 4.5 ดู Service และ Ingress / Check Services and Ingress

```bash
kubectl get svc -n ultra-sync-prod
kubectl get ingress -n ultra-sync-prod
```

---

## 5. Frontend (Flutter) — Release Build

### 5.1 ตั้งค่า Production URL / Configure Production URL

แก้ไข `mobile/lib/core/config/app_config.dart`:

```dart
const String baseUrl = 'https://api.your-domain.com';
```

### 5.2 สร้าง Release Build / Create Release Build

```bash
cd mobile

# ดาวน์โหลด dependencies
flutter pub get

# Generate code
dart run build_runner build --delete-conflicting-outputs

# Build Android (APK หรือ AAB สำหรับ Play Store)
flutter build apk --release
# หรือ / or
flutter build appbundle --release   # แนะนำสำหรับ Play Store / recommended for Play Store

# Build iOS (ต้องใช้ macOS และ Xcode)
flutter build ipa --release
```

Output:
- Android APK: `mobile/build/app/outputs/apk/release/app-release.apk`
- Android AAB: `mobile/build/app/outputs/bundle/release/app-release.aab`
- iOS IPA: `mobile/build/ios/archive/Runner.xcarchive`

### 5.3 อัปโหลด / Upload

```bash
# Android → Google Play Store ผ่าน Console หรือ fastlane
# iOS → App Store Connect ผ่าน Xcode Organizer หรือ fastlane

# ตรวจสอบ APK ก่อนอัปโหลด / Inspect APK before upload
flutter build apk --analyze-size
```

---

## 6. Service Integration Checklist

ตรวจสอบทุกข้อก่อนประกาศ Go-Live / Verify all items before declaring Go-Live:

```
Infrastructure
[ ] kubectl get pods -n ultra-sync-prod → ทุก Pod สถานะ "Running"
[ ] kubectl get ingress -n ultra-sync-prod → มี External IP
[ ] Vault ปลด Seal และ Policies ถูกต้อง

Backend Health
[ ] curl https://api.your-domain.com/health → {"status":"ok","services":{"auth":"up","wallet":"up","logistics":"up"}}
[ ] curl https://api.your-domain.com/api/v1/auth/health
[ ] curl https://api.your-domain.com/api/v1/wallet/health
[ ] curl https://api.your-domain.com/api/v1/shipments/health

Security
[ ] HTTPS ใช้งานได้ (TLS cert valid)
[ ] mTLS ระหว่าง Services ทำงานปกติ
[ ] JWT signing key โหลดจาก Vault สำเร็จ

Observability
[ ] Jaeger รับ Trace จากทุก Service
[ ] Prometheus scrape metrics ครบ
[ ] Grafana Dashboard แสดงผล Request Rate / Error Rate / Latency

Mobile
[ ] Build APK/IPA ไม่มี Error
[ ] App เชื่อมต่อ Production API ได้
[ ] Register, Login, Wallet, Shipment ทำงานครบ
```

### Smoke Test ก่อน Release / Pre-Release Smoke Test

```bash
PROD_URL=https://api.your-domain.com

# Register
curl -X POST ${PROD_URL}/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"smoke-test@test.com","password":"Smoke@1234","role":"user"}'

# Login
TOKEN=$(curl -s -X POST ${PROD_URL}/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"smoke-test@test.com","password":"Smoke@1234"}' \
  | jq -r '.data.access_token')

# Wallet Balance
curl ${PROD_URL}/api/v1/wallet/balance \
  -H "Authorization: Bearer ${TOKEN}"

# Create Shipment
curl -X POST ${PROD_URL}/api/v1/shipments \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"pickup_lat":13.75,"pickup_lng":100.5,"dropoff_lat":13.8,"dropoff_lng":100.55}'
```

---

## 7. Load Testing Against Production

> **ข้อควรระวัง / Warning:** รัน Load Test เฉพาะช่วง Maintenance Window หรือ Staging — ไม่ควรรันตรงบน Production ที่มี User จริง

```bash
cd tests/k6
npm install
npm run build

# รันพร้อม Production URL / Run against production URL
k6 run \
  -e BASE_URL=https://api.your-domain.com \
  --out influxdb=http://influxdb:8086/k6 \
  dist/auth.js

k6 run \
  -e BASE_URL=https://api.your-domain.com \
  dist/wallet.js

k6 run \
  -e BASE_URL=https://api.your-domain.com \
  dist/logistics.js
```

Threshold ที่ต้องผ่าน / Required Thresholds:

| Metric | Target |
|--------|--------|
| `http_req_failed` | < 1% |
| `http_req_duration p(99)` | < 500ms (auth) |
| `http_req_duration p(95)` | < 600ms (wallet) |
| `http_req_duration p(95)` | < 800ms (logistics) |
| `error_rate` | < 2% |

---

## 8. Observability & Monitoring

### URLs (Production) / Production URLs

| Tool | URL |
|------|-----|
| Jaeger | https://jaeger.your-domain.com |
| Grafana | https://grafana.your-domain.com |
| Prometheus | https://prometheus.your-domain.com |

### ดู Log แบบ Real-time / Stream Logs in Real-time

```bash
# Log ทุก Pod ใน namespace
kubectl logs -n ultra-sync-prod -l app=api-gateway -f

# Log ทุก Service พร้อมกัน (ใช้ stern)
stern -n ultra-sync-prod "ultra-sync" --since 5m
```

### ดู Resource Usage / Check Resource Usage

```bash
kubectl top pods -n ultra-sync-prod
kubectl top nodes
```

### ตรวจสอบ Trace ใน Jaeger / Check Traces in Jaeger

1. เปิด https://jaeger.your-domain.com
2. เลือก Service (เช่น `auth-service`)
3. ดู Trace แต่ละ Request และ Latency breakdown

---

## 9. Rollback Procedure

ถ้า Deploy แล้วมีปัญหา ให้ Rollback ทันที / If deployment causes issues, rollback immediately:

### 9.1 Rollback ด้วย Helm / Helm Rollback

```bash
# ดู History ของ Helm Release
helm history auth -n ultra-sync-prod
helm history wallet -n ultra-sync-prod
helm history logistics -n ultra-sync-prod
helm history api-gateway -n ultra-sync-prod

# Rollback ไปเวอร์ชันก่อนหน้า (REVISION = เลขจาก history)
helm rollback auth <REVISION> -n ultra-sync-prod --wait
helm rollback wallet <REVISION> -n ultra-sync-prod --wait
helm rollback logistics <REVISION> -n ultra-sync-prod --wait
helm rollback api-gateway <REVISION> -n ultra-sync-prod --wait
```

### 9.2 ตรวจสอบหลัง Rollback / Verify After Rollback

```bash
kubectl get pods -n ultra-sync-prod
curl https://api.your-domain.com/health
```

### 9.3 Rollback Flutter App / Flutter App Rollback

- **Android:** ยืนยันการ Rollback ผ่าน Google Play Console → Production → Create new release with previous APK/AAB
- **iOS:** Submit previous build ผ่าน App Store Connect
