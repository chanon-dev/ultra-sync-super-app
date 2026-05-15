# Implementation Phases (แผนการดำเนินงาน)

## Phase 1: Enterprise Foundation (สัปดาห์ที่ 1)
- **Goal:** วางรากฐาน Infrastructure และ Design System
- **Tasks:**
    - [ ] Setup Docker Compose (Kafka, Postgres, Redis, Vault, Jaeger).
    - [ ] ออกแบบ Protobuf contracts สำหรับทุก Microservice.
    - [ ] ประกาศใช้ Coding Conventions & Linting Rules (CONVENTIONS.md).
    - [ ] Flutter Clean Architecture + BLoC Boilerplate.
    - [ ] Setup API Gateway with Rate Limiting & Auth Middleware.

## Phase 2: Core Services & Observability (สัปดาห์ที่ 2)
- **Goal:** ระบบสมาชิกและการตรวจสอบ (Observability)
- **Tasks:**
    - [ ] Implement Auth Service (gRPC + Vault).
    - [ ] Integrate OpenTelemetry (OTel) ในทุก Go Service.
    - [ ] Setup Prometheus & Grafana Dashboards.
    - [ ] Flutter Auth BLoC + Biometric Login.

## Phase 3: Event-Driven Logistics (สัปดาห์ที่ 3-4)
- **Goal:** ระบบขนส่งแบบ Real-time และ Event Streaming
- **Tasks:**
    - [ ] Logistics Service (PostGIS + Redis Tracking).
    - [ ] Kafka integration (Order created -> Notify driver).
    - [ ] Flutter Maps + Background GPS Tracking.
    - [ ] Circuit Breaker implementation ใน Service communication.

## Phase 4: Secure Wallet & Transactions (สัปดาห์ที่ 5)
- **Goal:** ระบบการเงินความปลอดภัยสูง
- **Tasks:**
    - [ ] Wallet Service (Acid Transactions + Audit Logs).
    - [ ] Distributed Transactions (Saga Pattern).
    - [ ] QR Payment & Secure PIN entry ใน Flutter.

## Phase 5: Hardening & Production Ready (สัปดาห์ที่ 6)
- **Goal:** การทดสอบประสิทธิภาพและความปลอดภัย
- **Tasks:**
    - [ ] Load Testing ด้วย k6.
    - [ ] Automated E2E Testing ด้วย Patrol.
    - [ ] CI/CD Pipeline (GitHub Actions).
    - [ ] Kubernetes Manifests / Helm Charts.
