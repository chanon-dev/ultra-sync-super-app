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
- [ ] **2.1 API Gateway**
    - [ ] Implement Reverse Proxy และ Rate Limiting.
    - [ ] ระบบ Middleware สำหรับตรวจสอบ JWT.
- [ ] **2.2 Auth Microservice**
    - [ ] ระบบ Register/Login (Go + PostgreSQL).
    - [ ] ระบบ Token Rotation (Access/Refresh Token).
    - [ ] Integration กับ Vault สำหรับเก็บ Signing Key.
- [ ] **2.3 Flutter Auth Module**
    - [ ] Setup AuthBLoC และ Repository.
    - [ ] หน้าจอ Login/Register (Premium UI).
    - [ ] ระบบสแกนลายนิ้วมือ/ใบหน้า (Biometrics).

---

## 📍 Phase 3: Logistics & Real-time Tracking (สัปดาห์ที่ 3-4)
- [ ] **3.1 Logistics Microservice**
    - [ ] ระบบจัดการคำสั่งซื้อ (Orders CRUD).
    - [ ] Driver Dispatching Logic (Matching).
    - [ ] ระบบพิกัด GPS (PostGIS).
- [ ] **3.2 Real-time Infrastructure**
    - [ ] WebSocket Server ใน Go สำหรับยิงพิกัดคนขับ.
    - [ ] Kafka Producer/Consumer สำหรับอัปเดตสถานะออเดอร์.
- [ ] **3.3 Flutter Logistics Module**
    - [ ] Google Maps Integration.
    - [ ] Background Location Service.
    - [ ] หน้าจอ Tracking พร้อม Marker Animation.

---

## 💰 Phase 4: Secure Wallet & Transactions (สัปดาห์ที่ 5)
- [ ] **4.1 Wallet Microservice**
    - [ ] ระบบกระเป๋าเงิน (Balance Management).
    - [ ] Distributed Transactions (Saga Pattern) ระหว่าง Logistics และ Wallet.
    - [ ] Audit Trail logging สำหรับทุกธุรกรรม.
- [ ] **4.2 Flutter Wallet Module**
    - [ ] หน้าจอยอดเงินและประวัติธุรกรรม (Pagination).
    - [ ] ระบบ QR Code Generator และ Scanner.

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

## 🏁 Project Completion Status: 20%

Phase 1 complete — Phase 2 Auth Service implementation is next.
