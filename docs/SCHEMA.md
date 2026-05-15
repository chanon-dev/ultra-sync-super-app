# Enterprise Database Schema - Ultra-Sync Super App

## 1. Global Standards
- **ID:** ใช้ `UUID v4` เป็น Primary Key เพื่อความปลอดภัยและรองรับการทำ Distributed Database.
- **Timestamps:** ใช้ `TIMESTAMP WITH TIME ZONE` (TIMESTAMPTZ) เสมอ.
- **Precision:** ใช้ `DECIMAL(20, 4)` สำหรับเงินและความแม่นยำสูง.
- **Indexing:**
    - Index บน Foreign Keys เสมอ.
    - Index บนคอลัมน์ที่ใช้ในการ Filter บ่อยๆ (status, email, created_at).
    - Composite Index สำหรับการ Pagination (e.g., `(created_at, id)`).

---

## 2. Auth & User Service (AuthDB)

### Users Table
| Column | Type | Constraints |
| --- | --- | --- |
| id | UUID | PRIMARY KEY |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL |
| role | VARCHAR(20) | CHECK (role IN ('user', 'driver', 'admin')) |
| status | VARCHAR(20) | DEFAULT 'pending_verify' |
| mfa_secret | VARCHAR(255) | NULLABLE |
| last_login_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | DEFAULT NOW() |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() |

### Sessions Table (Distributed Session)
| Column | Type | Constraints |
| --- | --- | --- |
| id | UUID | PRIMARY KEY |
| user_id | UUID | FK -> Users.id |
| refresh_token | VARCHAR(512) | UNIQUE |
| expires_at | TIMESTAMPTZ | |
| is_revoked | BOOLEAN | DEFAULT FALSE |

---

## 3. Logistics Service (LogisticsDB)

### Shipments Table
| Column | Type | Constraints |
| --- | --- | --- |
| id | UUID | PRIMARY KEY |
| order_no | VARCHAR(50) | UNIQUE (Index) |
| sender_id | UUID | NOT NULL |
| driver_id | UUID | NULLABLE (Index) |
| status | VARCHAR(20) | Index |
| pickup_geo | GEOMETRY(POINT, 4326) | PostGIS Index |
| dropoff_geo | GEOMETRY(POINT, 4326) | PostGIS Index |
| price | DECIMAL(20,4) | |
| created_at | TIMESTAMPTZ | Index for Pagination |

### ShipmentLogs Table (Partitioned by Month)
| Column | Type | Constraints |
| --- | --- | --- |
| id | BIGSERIAL | PRIMARY KEY |
| shipment_id | UUID | FK (Index) |
| status | VARCHAR(20) | |
| current_geo | GEOMETRY(POINT, 4326) | |
| metadata | JSONB | เก็บข้อมูลเพิ่มเติม เช่น ความเร็ว, อุณหภูมิ |
| created_at | TIMESTAMPTZ | |

---

## 4. Wallet Service (WalletDB)

### Wallets Table
| Column | Type | Constraints |
| --- | --- | --- |
| user_id | UUID | PRIMARY KEY |
| balance | DECIMAL(20,4) | DEFAULT 0.0000 |
| currency | VARCHAR(10) | DEFAULT 'THB' |
| version | INT | Optimistic Locking สำหรับการโอนเงิน |
| updated_at | TIMESTAMPTZ | |

### Transactions Table
| Column | Type | Constraints |
| --- | --- | --- |
| id | UUID | PRIMARY KEY |
| wallet_id | UUID | FK |
| type | VARCHAR(20) | topup, payout, payment |
| amount | DECIMAL(20,4) | |
| balance_after | DECIMAL(20,4) | สำหรับ Audit trail |
| idempotency_key | VARCHAR(255) | UNIQUE Index |
| created_at | TIMESTAMPTZ | Index for Pagination |
