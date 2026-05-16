# 🚀 Master Checklist: Ultra-Sync Super App

ใช้ไฟล์นี้เพื่อติดตามความคืบหน้าของโปรเจกต์ เมื่อทำเสร็จในแต่ละข้อ ให้เปลี่ยน `[ ]` เป็น `[x]`.

---

## 🏗️ Phase 1: Enterprise Foundation (สัปดาห์ที่ 1)
- [x] **1.1 Project Initialization**
    - [x] สร้างโครงสร้างโฟลเดอร์ Backend (Services, API Gateway, Proto).
    - [x] สร้างโปรเจกต์ Flutter พร้อมโครงสร้าง Clean Architecture.
    - [x] ประกาศใช้ Coding Conventions ในทีม.
- [x] **1.2 Infrastructure Setup (Docker Compose)**
    - [x] PostgreSQL + PostGIS (3 instances สำหรับ 3 services).
    - [x] Apache Kafka + Zookeeper (Event Streaming).
    - [x] Redis (Tracking Cache).
    - [x] HashiCorp Vault (Secrets).
    - [x] Jaeger + Prometheus (Observability).
- [x] **1.3 API Contracts & Protobuf**
    - [x] เขียนไฟล์ `.proto` สำหรับทุก Microservice.
    - [ ] Generate Go code และ Dart code จาก Protobuf. *(ต้องติดตั้ง `buf` CLI ก่อน)*

---

## 🔐 Phase 2: Core Services & Auth (สัปดาห์ที่ 2)
- [x] **2.1 API Gateway**
    - [x] Implement Reverse Proxy และ Rate Limiting.
    - [x] ระบบ Middleware สำหรับตรวจสอบ JWT (RS256, wired to /shipments & /wallet routes).
- [x] **2.2 Auth Microservice**
    - [x] ระบบ Register/Login (Go + PostgreSQL).
    - [x] ระบบ Token Rotation (Access/Refresh Token).
    - [x] RSA public-key endpoint (`GET /api/v1/auth/public-key`) for gateway bootstrap.
    - [ ] Integration กับ Vault สำหรับเก็บ Signing Key. *(prod: replace ephemeral RSA key)*
- [x] **2.3 Flutter Auth Module**
    - [x] Setup AuthBLoC (login, register, logout, check-auth, biometrics).
    - [x] Repository + UseCase layer (Login, Register, Logout, CheckAuth).
    - [x] หน้าจอ Login/Register (Premium dark UI, go_router navigation).
    - [x] ระบบสแกนลายนิ้วมือ/ใบหน้า (BiometricService + local_auth).
    - [x] go_router setup with auth guards (splash → login/home redirect).
    - [x] HomePage with feature grid (Phase 3/4 placeholders).

---

## 📍 Phase 3: Logistics & Real-time Tracking (สัปดาห์ที่ 3-4)
- [x] **3.1 Logistics Microservice**
    - [x] ระบบจัดการคำสั่งซื้อ (Orders CRUD — POST/GET /shipments, GET /shipments/:id, PATCH /shipments/:id/status).
    - [x] Driver Dispatching Logic (AssignDriver usecase + POST /drivers/location).
    - [x] ระบบพิกัด GPS (lat/lng columns + Redis location cache).
- [x] **3.2 Real-time Infrastructure**
    - [x] SSE endpoint (GET /api/v1/shipments/:id/track) พร้อม TrackingHub fan-out.
    - [ ] Kafka Producer/Consumer สำหรับอัปเดตสถานะออเดอร์. *(NoopPublisher ใช้แทนใน dev; swap in IBM/sarama ใน prod)*
- [x] **3.3 Flutter Logistics Module**
    - [x] ShipmentsPage (list + status badges + cursor pagination ready).
    - [x] CreateShipmentPage (coordinate input + route preview).
    - [x] TrackingPage (live badge + status timeline + 5s polling; Google Maps placeholder pending API key).
    - [ ] Background Location Service (Phase 4 driver app feature).
    - [ ] Google Maps tile integration (add MAPS_API_KEY to enable).

---

## 💰 Phase 4: Secure Wallet & Transactions (สัปดาห์ที่ 5)
- [x] **4.1 Wallet Microservice**
    - [x] ระบบกระเป๋าเงิน (Balance Management) — optimistic locking via `version` column, auto-provision on first access.
    - [x] Idempotency via `X-Idempotency-Key` on topup endpoint (UNIQUE index on `transactions.idempotency_key`).
    - [ ] Distributed Transactions (Saga Pattern) ระหว่าง Logistics และ Wallet. *(planned for Phase 5 / post-MVP)*
    - [ ] Audit Trail logging สำหรับทุกธุรกรรม. *(transactions table serves as audit trail; structured log stream deferred)*
- [x] **4.2 Flutter Wallet Module**
    - [x] หน้าจอยอดเงินและประวัติธุรกรรม (cursor-based pagination, dark gradient BalanceCard).
    - [x] Top Up flow — preset chips + TextFormField + idempotency key + BLoC + SnackBar feedback.
    - [ ] ระบบ QR Code Generator และ Scanner. *(deferred — out of MVP scope)*

---

## 🛠️ Phase 5: Hardening & Production Ready (สัปดาห์ที่ 6)
- [ ] **5.1 Testing & Performance**
    - [ ] เขียน Unit Test ให้ครอบคลุม > 80%.
    - [ ] Load Testing ด้วย k6 (Simulate users).
    - [ ] Automated E2E Testing ด้วย Patrol (Flutter).
- [ ] **5.2 CI/CD & Cloud**
    - [ ] GitHub Actions Pipeline (Test & Build).
    - [ ] Kubernetes Manifests และ Helm Charts.
    - [ ] ระบบ Monitoring Dashboard ใน Grafana.

---

## 🏁 Project Completion Status: 65%

Phase 1, 2 & 3 complete — Phase 4 Wallet & Transactions is next.
