# Product Requirements Document (PRD) - Ultra-Sync Super App

## 1. Product Overview
แอปพลิเคชันรูปแบบ **Super App** ที่รวมระบบ Logistics, Digital Wallet, และ Real-time Communication ไว้ด้วยกัน โดยเน้นเทคโนโลยีระดับสูง

## 2. Target Audience
- ผู้ใช้งานที่ต้องการส่งของ (Senders)
- คนขับรถส่งของ (Drivers)
- ผู้ที่ต้องการทำธุรกรรมทางการเงินผ่าน QR Code

## 3. Functional Requirements (ความต้องการทางฟังก์ชัน)

### 3.1 Authentication & Profile
- **FR1:** Support Email/Password และ Biometric Login (FaceID/Fingerprint).
- **FR2:** User Profile management (Upload images using Flutter Camera/Gallery).

### 3.2 Real-time Logistics
- **FR3:** Driver real-time location tracking (GPS) บนแผนที่.
- **FR4:** Automated Order Matching using Go concurrency (Goroutines).
- **FR5:** Navigation support สำหรับคนขับ

### 3.3 Digital Wallet & Payment
- **FR6:** QR Code Scanning for payments.
- **FR7:** Transaction history with advanced filtering.
- **FR8:** Secure money transfer logic (Atomic transactions in Go).

### 3.4 Chat & Notifications
- **FR9:** Real-time chat between Driver and User (WebSockets).
- **FR10:** Push Notifications for order updates (FCM).

## 4. Technical Specifications (ข้อกำหนดทางเทคนิค)

### Architecture: Microservices
- **Inter-service Communication:** gRPC (Internal), REST/WebSockets (External).
- **Service Discovery:** Environment-based or Docker DNS.

### Frontend (Flutter)
- **Architecture:** Clean Architecture with DDD & SOLID.
- **State Management:** BLoC (Flutter BLoC library).
- **Local DB:** Isar.

### Backend (Go)
- **Pattern:** Hexagonal Architecture.
- **Framework:** Gin (API Gateway), Connect/gRPC (Internal).
- **Database:** PostgreSQL per Service (Database isolation).
- **Cache:** Redis for GPS Tracking & Session.

## 5. Non-Functional Requirements
- **Security:** JWT Authentication with RSA encryption.
- **Scalability:** Dockerized services for horizontal scaling.
- **UI/UX:** Premium Design System (Glassmorphism, Dark/Light mode).
