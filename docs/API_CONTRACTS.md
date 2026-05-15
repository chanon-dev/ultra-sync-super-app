# Enterprise API Design & Contracts - Ultra-Sync Super App

## 1. API Design Guidelines (Best Practices)

### 1.1 Response Standard Envelope
ทุกการตอบกลับจาก API จะต้องอยู่ในรูปแบบนี้เสมอ:
```json
{
  "data": {}, // ข้อมูลหลัก (Object หรือ Array)
  "meta": {   // ข้อมูลเสริม (Pagination, System Status)
    "request_id": "uuid",
    "timestamp": "ISO8601"
  },
  "error": null // ข้อมูล Error (ถ้ามี)
}
```

### 1.2 Cursor-based Pagination
เราใช้ **Cursor** แทน Offset เพื่อประสิทธิภาพ (Performance) และความถูกต้องของข้อมูล (Data Consistency) เมื่อมีการเพิ่มข้อมูลใหม่:
- `limit`: จำนวนข้อมูลที่ต้องการ (Default: 20, Max: 100).
- `after`: Cursor ค่าล่าสุดที่ได้รับ.
- `before`: Cursor ค่าแรกสุดในหน้าปัจจุบัน (สำหรับการย้อนกลับ).

### 1.3 Idempotency
สำหรับ API ที่มีการสร้างข้อมูลหรือตัดเงิน (POST/PATCH) จะต้องรองรับ `X-Idempotency-Key` ใน Header เพื่อป้องกันการทำรายการซ้ำ (Double Submission).

---

## 2. Logistics Service API

### GET `/api/v1/shipments` (List Shipments)
ดึงรายการออเดอร์พร้อมระบบ Filter และ Pagination

**Query Parameters:**
- `status`: `pending`, `active`, `completed`, `cancelled` (Comma separated)
- `start_date`: ISO8601
- `end_date`: ISO8601
- `cursor`: string
- `limit`: int

**Success Response (200 OK):**
```json
{
  "data": [
    {
      "id": "uuid",
      "order_no": "ORD-2023-001",
      "status": "shipping",
      "origin": { "address": "...", "lat": 13.1, "lng": 100.1 },
      "destination": { "address": "...", "lat": 13.2, "lng": 100.2 },
      "price": 150.00,
      "created_at": "2023-10-27T10:00:00Z"
    }
  ],
  "meta": {
    "next_cursor": "base64_encoded_cursor",
    "has_more": true,
    "request_id": "trace-id-123"
  }
}
```

---

## 3. Wallet Service API

### GET `/api/v1/wallet/transactions` (Transaction History)
ดึงประวัติการเงินแบบละเอียด

**Query Parameters:**
- `type`: `topup`, `payment`, `transfer`, `payout`
- `cursor`: string
- `limit`: int

**Success Response (200 OK):**
```json
{
  "data": [
    {
      "id": "uuid",
      "type": "payment",
      "amount": -150.00,
      "balance_after": 1100.50,
      "reference_id": "ORD-2023-001",
      "note": "Payment for delivery",
      "created_at": "2023-10-27T10:05:00Z"
    }
  ],
  "meta": {
    "next_cursor": "base64_encoded_cursor",
    "has_more": false
  }
}
```

---

## 4. Error Response Standard
เมื่อเกิดความผิดพลาด ระบบจะคืนค่า **4xx** หรือ **5xx** พร้อมรายละเอียด:

```json
{
  "data": null,
  "meta": { "request_id": "trace-id-123" },
  "error": {
    "code": "VAL-001",
    "message": "Invalid input data",
    "details": [
      { "field": "amount", "issue": "must be greater than 0" }
    ]
  }
}
```

---

## 5. Global Status Codes
- `200 OK`: สำเร็จ
- `201 Created`: สร้างข้อมูลสำเร็จ
- `400 Bad Request`: ข้อมูลที่ส่งมาไม่ถูกต้อง
- `401 Unauthorized`: Token หมดอายุหรือไม่ถูกต้อง
- `403 Forbidden`: ไม่มีสิทธิ์เข้าถึงฟีเจอร์นี้
- `429 Too Many Requests`: เรียก API เกินกำหนด (Rate Limit)
- `500 Internal Server Error`: ปัญหาที่ฝั่ง Server
