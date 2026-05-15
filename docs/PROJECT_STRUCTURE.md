# Project Structure - Ultra-Sync Super App

เอกสารนี้ระบุโครงสร้างโฟลเดอร์และกฎการใช้งาน (Do's & Don'ts) เพื่อให้ระบบเป็นระเบียบและลดปัญหา Dependency Injection / Tight Coupling.

---

## 🐹 1. Backend Structure (Go Microservices)

โครงสร้างแบบ Monorepo เพื่อการจัดการ Protobuf และ Shared Libraries ที่มีประสิทธิภาพ:

```text
/backend
├── /api-gateway        # Entry point สำหรับ Mobile (REST/Websocket)
├── /services           # โฟลเดอร์รวม Microservices
│   ├── /auth           # Authentication Service
│   ├── /logistics      # Logistics & Tracking Service
│   └── /wallet         # Wallet & Payment Service
│       ├── /cmd        # Entry point (main.go)
│       ├── /internal   # Private code (Hexagonal Architecture)
│       │   ├── /domain # Entities & Port Interfaces
│       │   ├── /usecase# Business Logic (Application layer)
│       │   └── /adapter# Adapters (DB, gRPC, Redis, Kafka)
│       └── /test       # Integration & Mock tests
├── /proto              # Shared Protobuf definitions (.proto files)
├── /pkg                # Shared libraries (Logger, Auth Middleware, Tracing)
└── docker-compose.yaml # Local development infrastructure
```

### 🚫 Backend Rules (ห้ามทำเด็ดขาด)
- **/cmd:** ห้ามเขียน Business Logic ในไฟล์ `main.go` ให้ใช้สำหรับ Setup Dependency เท่านั้น.
- **/internal/domain:** **ห้าม Import** แพ็กเกจอื่นจากภายนอกเด็ดขาด (Pure Go Only).
- **/internal/usecase:** ห้ามเรียกใช้ SQL Query หรือติดต่อ Redis โดยตรง (ต้องเรียกผ่าน Port Interface).
- **Across Services:** ห้ามให้ Service หนึ่ง Import โฟลเดอร์ `/internal` ของอีก Service หนึ่ง (ต้องคุยผ่าน gRPC เท่านั้น).

---

## 💙 2. Mobile Structure (Flutter - Clean Architecture)

โครงสร้างแยกตาม Feature (Feature-first) เพื่อการ Scalability:

```text
/mobile
├── /lib
│   ├── /core           # Shared elements (Theme, Network, Error Handling)
│   ├── /features       # โฟลเดอร์รวมฟีเจอร์หลัก
│   │   ├── /auth       # Feature: Authentication
│   │   ├── /tracking   # Feature: Real-time Tracking
│   │   └── /wallet     # Feature: Digital Wallet
│   │       ├── /data         # Data source, Models, Repository Impl
│   │       ├── /domain       # Entities, Use Cases, Repository Interfaces
│   │       └── /presentation # BLoC, Pages, Widgets
│   └── main.dart       # Entry point
├── /assets             # Images, Fonts, Lottie animations
└── /test               # Unit, Widget, and Integration tests
```

### 🚫 Mobile Rules (ห้ามทำเด็ดขาด)
- **/lib/core:** ห้ามใส่ Business Logic เฉพาะของฟีเจอร์ลงในนี้.
- **/domain:** ห้าม Import ไฟล์จากชั้น `presentation` หรือ `data` เข้ามา (Domain ต้องเป็นอิสระ).
- **/presentation:** ห้ามเขียน Logic การคำนวณที่ซับซ้อน (เช่น การคำนวณภาษี) ใน Widget ให้ทำใน Use Case เท่านั้น.
- **Data Layer:** ห้ามใช้ Entity ของ Domain เป็นตัวรับ JSON โดยตรง (ต้องใช้ Model และทำ Mapping).

---

## 🛠️ 3. Shared Global Rules
- **Configuration:** ทุกการตั้งค่าต้องอยู่ที่โฟลเดอร์ Root ของแต่ละแอป หรือผ่าน Environment Variables เท่านั้น.
- **Tests:** ทุกโฟลเดอร์ฟีเจอร์ต้องมีโฟลเดอร์ทดสอบคู่ขนานกันเสมอ.
