# Coding Standards & Architecture Conventions

เอกสารนี้รวบรวมกฎและแนวทางปฏิบัติ (Best Practices) เพื่อให้ทีมพัฒนาไปในทิศทางเดียวกันและรักษาคุณภาพของระบบในระดับ Enterprise.

---

## 🐹 1. Go (Backend) Conventions

### 1.1 Naming & Structure
- **Package Names:** ต้องสั้น, เป็นตัวพิมพ์เล็กทั้งหมด, ไม่ใช้ underscore (เช่น `authservice`, `walletrepo`).
- **Variables:** ใช้ `camelCase`. สำหรับตัวย่อ (Initialisms) ให้ใช้ตัวพิมพ์ใหญ่ทั้งหมด (เช่น `userID` แทน `userId`, `url` แทน `Url`).
- **Interfaces:** ตั้งชื่อตามพฤติกรรม (เช่น `Reader`, `Writer`, `Storer`) และลงท้ายด้วย `-er` ถ้าเป็นไปได้.

### 1.2 Error Handling
- **Rule:** ห้ามละเลย Error (ห้ามใช้ `_ , err := ...`).
- **Rule:** ใช้การ Wrap Error เพื่อรักษา Stack Trace: `return fmt.Errorf("failed to save user: %w", err)`.
- **Rule:** Error ที่ส่งกลับไปหา Client ต้องเป็นมาตรฐานเดียวกัน (ตามที่ระบุใน `API_CONTRACTS.md`).

### 1.3 Hexagonal Architecture Rules
- ✅ **DO:** Domain Layer ต้องไม่นำเข้า (Import) แพ็กเกจจาก Infrastructure Layer.
- ✅ **DO:** ใช้ Dependency Injection ผ่าน Constructor เสมอ.
- ❌ **DON'T:** ห้ามใส่ SQL Query หรือการติดต่อ DB ภายใน Domain/Use Case.
- ❌ **DON'T:** ห้ามใช้ `init()` function สำหรับการ Setup logic สำคัญ (ทำให้เทสยาก).

---

## 💙 2. Flutter (Mobile) Conventions

### 2.1 UI & Layout
- **Files:** ใช้ `snake_case.dart`.
- **Classes:** ใช้ `PascalCase`.
- **Widgets:** แยก Widget ย่อยๆ ออกเป็นไฟล์หรือ Method เพื่อไม่ให้ไฟล์เดียวมีโค้ดเกิน 300 บรรทัด.

### 2.2 BLoC Management
- ✅ **DO:** ทุก State ต้องเป็น **Immutable** (แนะนำให้ใช้ `freezed` หรือ `equatable`).
- ✅ **DO:** ส่งเฉพาะ Event เข้าไปใน BLoC และรับเฉพาะ State ออกมาแสดงผล.
- ❌ **DON'T:** ห้ามแก้ค่า State โดยตรงภายใน Widget.
- ❌ **DON'T:** ห้ามมี Logic การคำนวณราคาหรือ Business Logic ภายใน `build()` method.

### 2.3 Clean Architecture Rules
- ✅ **DO:** Presentation Layer คุยกับ Domain Layer (Use Cases) เท่านั้น.
- ✅ **DO:** Data Layer รับผิดชอบการแปลง JSON เป็น Entities (Data Mapping).
- ❌ **DON'T:** ห้ามเรียก API ตรงจาก BLoC โดยไม่ผ่าน Use Case/Repository.

---

## 🛠️ 3. Global Rules (ห้ามละเมิด)

### 3.1 SOLID Principles Compliance
- **S:** หนึ่งไฟล์ หนึ่งหน้าที่ (One file, one responsibility).
- **O:** ขยายฟังก์ชันด้วยการสร้าง Adapter ใหม่ ไม่ใช่แก้โค้ดเดิม.
- **D:** High-level ไม่ขึ้นกับ Low-level (ใช้ Interface คั่นกลางเสมอ).

### 3.2 Performance & Safety
- **Rule:** ห้ามเก็บ Secrets (API Key, Passwords) ใน Source Code (ใช้ `.env` หรือ Vault).
- **Rule:** ทุกฟังก์ชันที่ทำ IO (DB, Network) ใน Go ต้องรับ `context.Context`.
- **Rule:** ใน Flutter งานที่ใช้ CPU หนักๆ ต้องรันใน `Isolate`.

### 3.3 Documentation
- ทุก Public Function และ Interface ต้องมี Comment อธิบายหน้าที่และ Parameter.
- โค้ดที่ซับซ้อน (Hacks) ต้องมีคอมเมนต์กำกับเหตุผลว่า "ทำไมถึงทำแบบนี้".
