# Ultra-Sync Frontend

Flutter frontend ของ Ultra-Sync Super App — รวม Logistics, Digital Wallet และ Real-time Chat ไว้ในแอปเดียว

---

## Tech Stack

| Layer | Library |
| --- | --- |
| State Management | `flutter_bloc ^9.1.1` + `bloc ^9.2.1` |
| Dependency Injection | `get_it ^9.2.1` + `injectable ^3.0.0` |
| Code Generation | `freezed ^3.0.0` + `json_serializable` |
| Routing | `go_router ^17.2.3` |
| Network | `dio ^5.4.3` |
| Functional Error Handling | `fpdart ^1.1.0` |
| Secure Storage | `flutter_secure_storage ^10.2.0` |
| Biometrics | `local_auth ^3.0.1` |
| Maps | `google_maps_flutter ^2.6.1` + `geolocator` |
| QR | `qr_flutter` + `mobile_scanner` |
| Real-time | `web_socket_channel ^3.0.0` |
| Reactive streams | `rxdart ^0.28.0` |

---

## Commands

```bash
# ติดตั้ง dependencies
flutter pub get

# รัน app
flutter run

# รัน tests ทั้งหมด
flutter test

# รัน test ไฟล์เดียว
flutter test test/features/auth/bloc/auth_bloc_test.dart

# Regenerate code (freezed, injectable) หลังแก้ entity/event/state
dart run build_runner build --delete-conflicting-outputs

# ตรวจ lint
flutter analyze
```

---

## Project Structure

```text
lib/
├── main.dart
├── core/
│   ├── di/
│   ├── error/
│   ├── extensions/
│   ├── network/
│   ├── ports/
│   ├── router/
│   ├── services/
│   ├── theme/
│   ├── utils/
│   └── widgets/
└── features/
    ├── auth/
    │   ├── data/
    │   │   ├── datasources/
    │   │   ├── models/
    │   │   └── repositories/
    │   ├── domain/
    │   │   ├── entities/
    │   │   ├── repositories/
    │   │   └── usecases/
    │   └── presentation/
    │       ├── bloc/
    │       └── pages/
    ├── logistics/  (โครงสร้างเหมือน auth)
    ├── wallet/     (โครงสร้างเหมือน auth)
    ├── home/
    ├── splash/
    └── profile/
```

---

## Project Structure — What / Why / When / Must Have

### `main.dart`

| | |
| --- | --- |
| **What** | Entry point ของแอป — bootstrap DI แล้ว call `runApp()` |
| **Why** | แยก wiring ออกจาก logic — `main.dart` รู้แค่ว่า "เริ่มต้นยังไง" ไม่รู้ business ใดๆ |
| **When** | แก้เมื่อต้องเพิ่ม global provider, เปลี่ยน env config, หรือ wrap root widget |
| **Must have** | `configureDependencies()`, `BlocProvider<AuthBloc>`, `MaterialApp.router` |

---

### `core/`

โฟลเดอร์กลางที่ทุก feature ใช้ร่วมกัน **ห้าม** import จาก `features/` เด็ดขาด — ถ้า import ได้แสดงว่าของนั้นไม่ควรอยู่ที่นี่

---

#### `core/di/`

| | |
| --- | --- |
| **What** | Dependency Injection setup — register ทุก singleton ที่แอปต้องการ |
| **Why** | รวม wiring ไว้จุดเดียว ทำให้ swap implementation ได้โดยไม่แตะ business code เช่น เปลี่ยน `FlutterSecureStorage` เป็น `Hive` แค่แก้ที่นี่ที่เดียว |
| **When** | แก้เมื่อเพิ่ม third-party lib ที่ injectable สร้างเองไม่ได้ เช่น `Dio`, `FlutterSecureStorage`, `LocalAuthentication` |
| **Must have** | `injection.dart` — manual registrations + `getIt.init()` และ `injection.config.dart` — AUTO-GENERATED ห้ามแก้มือ |

```text
core/di/
├── injection.dart         ← แก้ได้: register third-party + env config
└── injection.config.dart  ← ห้ามแก้: regenerate ด้วย build_runner
```

---

#### `core/error/`

| | |
| --- | --- |
| **What** | นิยาม error ทุกประเภทที่แอปอาจเจอ — ใช้ Dart 3 `sealed class` |
| **Why** | `sealed class` บังคับ compiler ให้ exhaustive switch — ถ้าเพิ่ม Failure ใหม่แล้วลืม handle ในทุกที่จะ compile error ทันที แทนที่จะ crash runtime |
| **When** | เพิ่ม subclass ใหม่เมื่อ backend มี error type ใหม่ที่ UI ต้องแสดงผลต่างกัน เช่น `RateLimitFailure`, `PaymentFailure` |
| **Must have** | `failures.dart` — sealed class ครอบคลุมทุก error scenario: `ServerFailure`, `NetworkFailure`, `UnauthorizedFailure`, `ValidationFailure`, `CacheFailure` |

```dart
// ทุก subclass ต้องอยู่ในไฟล์เดียวกัน (Dart 3 sealed class rule)
sealed class Failure extends Equatable { ... }
final class ServerFailure extends Failure { ... }
final class NetworkFailure extends Failure { ... }
final class UnauthorizedFailure extends Failure { ... }
final class ValidationFailure extends Failure { final List<FieldError> details; }
final class CacheFailure extends Failure { ... }
```

---

#### `core/extensions/`

| | |
| --- | --- |
| **What** | Extension methods บน type ที่ใช้บ่อย — `BuildContext`, `String`, `DateTime` |
| **Why** | ลด boilerplate ใน Widget เช่น `Theme.of(context).colorScheme` → `context.colorScheme` ทำให้ `build()` อ่านง่ายขึ้น |
| **When** | เพิ่มเมื่อเห็น pattern เดิมซ้ำ ≥ 3 ครั้งใน Widget เช่น `MediaQuery.sizeOf(context).width` → ทำ extension `context.screenWidth` |
| **Must have** | `build_context_ext.dart` — theme/router/screen size, `string_ext.dart` — capitalize/validation, `datetime_ext.dart` — formatting |

```text
core/extensions/
├── build_context_ext.dart  ← context.theme, context.router, context.screenWidth
├── string_ext.dart         ← 'hello'.capitalize(), str.isValidEmail, str.nullIfEmpty
└── datetime_ext.dart       ← date.formatted, date.dateOnly
```

---

#### `core/network/`

| | |
| --- | --- |
| **What** | HTTP client wrapper — `Dio` instance พร้อม interceptor สำหรับ auth |
| **Why** | Interceptor จัดการ token refresh อัตโนมัติทุก 401 โดย DataSource ไม่ต้องรู้เรื่อง token เลย — ถ้าแต่ละ DataSource จัดการเองจะ duplicate และ race condition |
| **When** | แก้เมื่อต้องเพิ่ม interceptor ใหม่ เช่น logging, retry logic, certificate pinning |
| **Must have** | `api_client.dart` — `ApiClient` class + `_AuthInterceptor` (token attach + 401 refresh + concurrent refresh lock) |

```text
core/network/
└── api_client.dart  ← Dio + _AuthInterceptor (auto refresh + Completer lock)
```

---

#### `core/ports/`

| | |
| --- | --- |
| **What** | Interface (abstract class) ที่ domain รู้จัก สำหรับ infrastructure ที่ใช้ข้าม feature |
| **Why** | "Ports & Adapters" pattern — domain import `TokenStorage` interface ไม่ใช่ `FlutterSecureStorage` โดยตรง ทำให้ swap storage engine ได้โดยไม่กระทบ domain และ test ได้ง่าย |
| **When** | สร้าง port ใหม่เมื่อ domain layer ต้องการ infrastructure ที่ไม่ใช่ business logic เช่น `CacheStorage`, `AnalyticsPort` |
| **Must have** | `token_storage.dart` — interface มี `getAccessToken()`, `getRefreshToken()`, `save()`, `clear()` |

```text
core/ports/
└── token_storage.dart  ← abstract class TokenStorage (implemented ใน core/services/)
```

---

#### `core/router/`

| | |
| --- | --- |
| **What** | Navigation config ทั้งหมด — route tree, auth guard, bottom tab shell |
| **Why** | รวม routing ไว้จุดเดียว ทำให้เห็นภาพรวมของ navigation flow ง่าย และ auth redirect logic อยู่แค่ที่นี่ที่เดียว ไม่กระจายใน Page |
| **When** | แก้เมื่อเพิ่ม route ใหม่, เพิ่ม tab, หรือเปลี่ยน auth redirect rule |
| **Must have** | `app_router.dart` — `GoRouter` + `redirect` callback + `_AuthChangeNotifier`, `main_shell.dart` — `StatefulShellRoute` wrapper สำหรับ bottom navigation |

```text
core/router/
├── app_router.dart  ← route tree + _redirect() + _AuthChangeNotifier
└── main_shell.dart  ← BottomNavigationBar + StatefulShellRoute
```

---

#### `core/services/`

| | |
| --- | --- |
| **What** | Infrastructure implementation ที่ใช้ข้าม feature — token storage, biometric, GPS |
| **Why** | Service เหล่านี้ไม่ใช่ business logic ของ feature ใด feature หนึ่ง แต่ทุก feature ใช้ร่วมกัน จึงอยู่ใน `core` แทน `features/auth/data` |
| **When** | เพิ่มเมื่อมี platform capability ที่หลาย feature ต้องใช้ เช่น `PushNotificationService`, `CrashReportingService` |
| **Must have** | `token_storage_impl.dart` — `FlutterSecureStorage` impl, `biometric_service.dart` — Face ID/Fingerprint, `location_service.dart` — GPS |

```text
core/services/
├── token_storage_impl.dart  ← implements TokenStorage ด้วย FlutterSecureStorage
├── biometric_service.dart   ← LocalAuthentication wrapper
└── location_service.dart    ← Geolocator wrapper
```

---

#### `core/theme/`

| | |
| --- | --- |
| **What** | Design system — สี, gradient, typography, และ ThemeData ทั้ง light/dark |
| **Why** | Single source of truth สำหรับ visual — ถ้าเปลี่ยนสีหลักแก้แค่ที่นี่ที่เดียว ทุก Widget อัพเดตอัตโนมัติ ป้องกัน hardcode color กระจัดกระจาย |
| **When** | แก้เมื่อ rebrand, เพิ่ม dark mode, หรือปรับ typography |
| **Must have** | `app_theme.dart` — `AppColors` (light), `AppColorsDark` (dark), `AppGradients`, `buildAppTheme()`, `buildDarkTheme()` |

```text
core/theme/
└── app_theme.dart
    ├── abstract class AppColors      ← color constants (light)
    ├── abstract class AppColorsDark  ← color constants (dark)
    ├── abstract class AppGradients   ← gradient constants
    ├── ThemeData buildAppTheme()     ← light theme
    └── ThemeData buildDarkTheme()    ← dark theme
```

---

#### `core/utils/`

| | |
| --- | --- |
| **What** | Pure Dart helper — base class และ stateless utility functions |
| **Why** | ไม่ควรอยู่ใน feature ใดๆ เพราะทุก feature ใช้ และไม่ใช่ UI ไม่ใช่ network |
| **When** | เพิ่มเมื่อมี helper ที่ pure (ไม่มี side effect) และถูก reuse ข้าม feature เช่น `CurrencyFormatter`, `PhoneValidator` |
| **Must have** | `use_case.dart` — `abstract class UseCase<Result, Params>`, `date_formatter.dart` — DateFormat wrapper |

```text
core/utils/
├── use_case.dart       ← abstract class UseCase<Result, Params> (base ของทุก use case)
└── date_formatter.dart ← static format helpers
```

---

#### `core/widgets/`

| | |
| --- | --- |
| **What** | Shared UI component — Widget ที่ใช้ข้าม feature โดยไม่มี business logic |
| **Why** | ป้องกัน copy-paste ถ้าแต่ละ feature สร้าง Button ของตัวเองจะมี style ต่างกัน แก้ทีต้องแก้หลายที่ Widget ที่นี่ style เหมือนกันทุก feature และแก้ที่เดียว |
| **When** | ย้าย Widget มาที่นี่เมื่อเห็น Widget แบบเดิมถูก copy ไปใช้ใน feature ที่ 2 |
| **Must have** | `app_button.dart`, `app_text_field.dart`, `app_snack_bar.dart`, `empty_state.dart` |

```text
core/widgets/
├── app_button.dart      ← gradient button + loading spinner
├── app_text_field.dart  ← styled TextFormField
├── app_snack_bar.dart   ← AppSnackBar.showError/showSuccess/showInfo
└── empty_state.dart     ← icon + message + optional action button
```

---

### `features/`

แต่ละ feature คือ **vertical slice** — มีครบทุก layer ของตัวเอง ไม่ยืม data/domain ของ feature อื่น

```text
features/
└── <feature_name>/
    ├── data/          ← พูดคุยกับ API / database / cache
    ├── domain/        ← business rules (pure Dart)
    └── presentation/  ← UI + BLoC
```

---

#### `features/<name>/domain/`

| | |
| --- | --- |
| **What** | หัวใจของ feature — นิยาม business rules, entities, และ interface ที่ต้องการ |
| **Why** | Domain ต้องเป็น Pure Dart ไม่มี Flutter, ไม่มี Dio, ไม่มี SharedPreferences — ทำให้ test ได้โดยไม่ต้องมี emulator หรือ server จริง |
| **When** | สร้างก่อนสุดเสมอ เพราะ data layer และ presentation layer depend บน domain |
| **Must have** | `entities/` — freezed data classes, `repositories/` — abstract interface, `usecases/` — 1 file ต่อ 1 operation |
| **ห้าม** | import จาก `data/` หรือ `presentation/` หรือ package ที่เป็น Flutter/infrastructure |

```text
domain/
├── entities/
│   ├── user.dart          ← @freezed abstract class — immutable + copyWith + equality ฟรี
│   └── user.freezed.dart  ← AUTO-GENERATED (ห้ามแก้มือ)
├── repositories/
│   └── auth_repository.dart  ← abstract class — บอกว่าต้องการอะไร ไม่บอกว่าทำยังไง
└── usecases/
    ├── login_usecase.dart       ← 1 class = 1 operation = 1 file
    ├── register_usecase.dart
    ├── logout_usecase.dart
    └── check_auth_usecase.dart
```

**Entity ต้องมี:**

- `@freezed abstract class` (ไม่ใช่ `class` ธรรมดา — freezed 3.x ต้องการ `abstract`)
- `part '<name>.freezed.dart'`
- `const factory` constructor
- `const <ClassName>._()` ถ้ามี computed getter
- computed getter / business rules (เช่น `bool get isActive => status == 'active'`)

**Repository Interface ต้องมี:**

- `abstract class` เท่านั้น — ห้ามมี implementation
- return type เป็น `Future<Either<Failure, T>>` เสมอ

**UseCase ต้องมี:**

- `implements UseCase<Result, Params>`
- `@lazySingleton` annotation
- `Params` class ที่ `extends Equatable`

---

#### `features/<name>/data/`

| | |
| --- | --- |
| **What** | Implementation ของ domain interface — เชื่อมต่อกับ API, database, cache |
| **Why** | แยก "วิธีดึงข้อมูล" ออกจาก "กฎธุรกิจ" — domain ไม่รู้ว่าข้อมูลมาจาก REST, GraphQL, หรือ local cache |
| **When** | สร้างหลัง domain — เพราะต้อง implement interface และแปลง Model เป็น Entity ที่ domain นิยามไว้ |
| **Must have** | `datasources/` — network calls, `models/` — JSON mapping + `toDomain()`, `repositories/` — impl ที่ห่อ exception เป็น `Either` |
| **ห้าม** | business logic ใน DataSource หรือ Model, Model extend Entity (ใช้ composition + `toDomain()` แทน) |

```text
data/
├── datasources/
│   └── auth_remote_data_source.dart
│       ├── abstract class AuthRemoteDataSource   ← interface (mock ตอน test)
│       └── @LazySingleton class Impl             ← Dio calls เท่านั้น, throw Failure ถ้า error
├── models/
│   └── user_model.dart
│       ├── class UserModel { fromJson() }        ← รู้จัก API field names
│       └── User toDomain()                       ← แปลงเป็น domain entity
└── repositories/
    └── auth_repository_impl.dart
        ├── @LazySingleton(as: AuthRepository)    ← register ผ่าน interface
        └── try/catch → Right(model.toDomain())   ← ห่อ exception เป็น Either
            └── on Failure → Left(f)
```

**Model ต้องมี:**

- `factory fromJson(Map<String, dynamic> json)` — explicit cast ทุก field ห้ามใช้ dynamic
- `T toDomain()` — แปลงเป็น domain entity
- ห้าม extend Entity — ใช้ composition เท่านั้น

---

#### `features/<name>/presentation/`

| | |
| --- | --- |
| **What** | UI layer — BLoC จัดการ state, Page แสดงผลและรับ input |
| **Why** | แยก "state management" ออกจาก "render" — BLoC test ได้โดยไม่ต้อง pump Widget, Page rebuild อัตโนมัติเมื่อ state เปลี่ยน |
| **When** | สร้างหลังสุด หลัง domain และ data พร้อมแล้ว |
| **Must have** | `bloc/` — event, state, bloc แยกไฟล์, `pages/` — Page ที่มีแค่ UI |
| **ห้าม** | business logic ใน `build()`, Widget เรียก Repository/DataSource โดยตรง, hardcode string/color ใน Widget |

```text
presentation/
├── bloc/
│   ├── auth_event.dart         ← @freezed sealed class — user actions / system triggers
│   ├── auth_event.freezed.dart ← AUTO-GENERATED
│   ├── auth_state.dart         ← @freezed sealed class — UI snapshot
│   ├── auth_state.freezed.dart ← AUTO-GENERATED
│   └── auth_bloc.dart          ← Event → UseCase → emit(State)
└── pages/
    ├── login_page.dart    ← BlocConsumer: listener=side effects, builder=UI
    └── register_page.dart
```

**Event ต้องมี:**

- `@freezed sealed class` (sealed บังคับ exhaustive switch)
- 1 factory constructor = 1 user action หรือ 1 system trigger

**State ต้องมี:**

- `@freezed sealed class`
- แต่ละ state แทน snapshot ของ UI — `loading`, `loaded`, `error` ไม่ใช่ flag หลายตัว
- ห้ามใช้ `bool isLoading; bool hasError;` — ใช้ sealed state แทน

**BLoC ต้องมี:**

- `@injectable` (ไม่ใช่ `@lazySingleton` — BLoC มี lifecycle ตาม Widget)
- handler method แยกสำหรับแต่ละ event
- ห้าม call repository โดยตรง — ผ่าน UseCase เท่านั้น

**Page ต้องมี:**

- `BlocProvider` — สร้าง BLoC + dispatch initial event
- `BlocConsumer` (หรือ `BlocBuilder` + `BlocListener`) — แยก side effects ออกจาก UI
- Private widget class (`_SomePart`) เมื่อ build method ยาวเกิน ~40 บรรทัด

---

## Architecture: Clean Architecture (Feature-first)

โปรเจคใช้ **Clean Architecture** แบ่งเป็น 3 layer ในแต่ละ feature:

```text
Presentation  →  Domain  ←  Data
(BLoC/Pages)     (UseCases  (Repository Impl
                  Entities   DataSources
                  Repo IF)   Models)
```

### กฎที่ห้ามละเมิด

| กฎ | เหตุผล |
| --- | --- |
| `presentation` ติดต่อ `domain` ผ่าน UseCase เท่านั้น | ถ้า Page เรียก Repository โดยตรง จะ test ยากและ coupling สูง |
| `domain` ไม่ import จาก `data` หรือ `presentation` | Domain ต้องเป็น pure Dart ไม่มี Flutter/infrastructure dependency |
| JSON parsing อยู่ใน `data/models` เท่านั้น | Entity ไม่รู้จัก API format — ป้องกัน API change กระทบ domain |
| `core/` ไม่ import จาก `features/` | core ต้อง reusable ไม่ขึ้นกับ feature ใดๆ |

---

## Layer ลึกๆ: แต่ละ layer ทำอะไร

### Domain Layer — "หัวใจของ feature"

ไม่มี Flutter import ไม่มี Dio ไม่มี SharedPreferences — มีแค่ Pure Dart

**Entity** — ข้อมูลหลักของ domain ใช้ `freezed` เพื่อได้ `copyWith`, immutability และ equality ฟรี:

```dart
// features/auth/domain/entities/user.dart
@freezed
abstract class User with _$User {
  const User._();
  const factory User({...}) = _User;

  // Business logic อยู่ที่นี่ — ไม่อยู่ใน Widget
  bool get isActive => status == 'active';
  bool get isDriver => role == 'driver';
}
```

**Repository Interface** — บอกว่า domain ต้องการ operation อะไร ไม่สนว่าจะดึงจาก API หรือ local cache:

```dart
// features/auth/domain/repositories/auth_repository.dart
abstract class AuthRepository {
  Future<Either<Failure, TokenPair>> login({...});
  Future<Either<Failure, Unit>> logout(String refreshToken);
}
```

**UseCase** — หนึ่ง UseCase = หนึ่ง operation ทางธุรกิจ รับ `Params` คืน `Either<Failure, Result>`:

```dart
// features/auth/domain/usecases/login_usecase.dart
@lazySingleton
class LoginUseCase implements UseCase<TokenPair, LoginParams> {
  final AuthRepository _repository;
  Future<Either<Failure, TokenPair>> call(LoginParams params) =>
      _repository.login(email: params.email, password: params.password);
}
```

---

### Data Layer — "พูดคุยกับโลกภายนอก"

**Model** — แปลง JSON → domain Entity ด้วย `toDomain()` (ไม่ extend Entity):

```dart
// features/auth/data/models/user_model.dart
class UserModel {
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['user_id'] as String,  // API ใช้ user_id, domain ใช้ id
    ...
  );
  User toDomain() => User(id: id, email: email, ...);
}
```

> **ทำไมไม่ให้ Model extends Entity?**
> ถ้า `UserModel extends User` แล้ว API เปลี่ยน field name → Entity พัง
> การใช้ `toDomain()` แยก API contract ออกจาก domain contract

**DataSource** — เรียก Dio ตรงๆ ไม่มี business logic:

```dart
// features/auth/data/datasources/auth_remote_data_source.dart
Future<TokenPairModel> login({...}) async {
  final response = await _client.dio.post('/api/v1/auth/login', data: {...});
  final body = response.data as Map<String, dynamic>;
  return TokenPairModel.fromJson(body['data'] as Map<String, dynamic>);
}
```

**Repository Impl** — glue ระหว่าง DataSource กับ Domain ห่อ exception ให้เป็น `Either<Failure, T>`:

```dart
// features/auth/data/repositories/auth_repository_impl.dart
Future<Either<Failure, TokenPair>> login({...}) async {
  try {
    final model = await _remote.login(email: email, password: password);
    return Right(model.toDomain());  // แปลง Model → Entity
  } on Failure catch (f) {
    return Left(f);
  }
}
```

---

### Presentation Layer — "แสดงผลและรับ input"

**Event** — สิ่งที่ user หรือระบบสั่งให้ BLoC ทำ ใช้ `freezed sealed class`:

```dart
// features/auth/presentation/bloc/auth_event.dart
@freezed
sealed class AuthEvent with _$AuthEvent {
  const factory AuthEvent.loginRequested({
    required String email,
    required String password,
  }) = AuthLoginRequested;
}
```

**State** — snapshot ของ UI ณ เวลานั้น ใช้ `freezed sealed class`:

```dart
// features/auth/presentation/bloc/auth_state.dart
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated({required TokenPair tokens}) = AuthAuthenticated;
  const factory AuthState.failure({required Failure failure}) = AuthFailureState;
}
```

**BLoC** — รับ Event → เรียก UseCase → emit State:

```dart
on<AuthLoginRequested>(_onLoginRequested);

Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
  emit(const AuthLoading());
  final result = await _login(LoginParams(email: event.email, password: event.password));
  result.fold(
    (failure) => emit(AuthFailureState(failure: failure)),
    (tokens) => emit(AuthAuthenticated(tokens: tokens)),
  );
}
```

---

## Error Handling

ใช้ **Dart 3 sealed class** + **fpdart Either** ทุก layer:

```dart
// core/error/failures.dart
sealed class Failure extends Equatable {
  final String message;
  final String code;
}

final class ServerFailure extends Failure { ... }
final class NetworkFailure extends Failure { ... }
final class UnauthorizedFailure extends Failure { ... }
final class ValidationFailure extends Failure {
  final List<FieldError> details;  // field-level errors
}
```

UI อ่าน error แบบ exhaustive — compiler บังคับให้ handle ทุก case:

```dart
switch (state) {
  AuthLoading() => const CircularProgressIndicator(),
  AuthAuthenticated(:final tokens) => const HomePage(),
  AuthFailureState(:final failure) => Text(failure.message),
  _ => const LoginPage(),
}
```

---

## Dependency Injection

ใช้ `injectable` annotation แล้ว run `build_runner` — ไม่ต้อง register manual:

```dart
@lazySingleton          // สร้างครั้งเดียว ใช้ทั้งแอป
class LoginUseCase implements UseCase<TokenPair, LoginParams> { ... }

@injectable             // สร้างใหม่ทุกครั้งที่ request
class AuthBloc extends Bloc<AuthEvent, AuthState> { ... }

@LazySingleton(as: AuthRepository)   // register ผ่าน interface
class AuthRepositoryImpl implements AuthRepository { ... }
```

---

## Auto Token Refresh

`ApiClient` มี `_AuthInterceptor` ที่จัดการ token โดยอัตโนมัติ:

1. ทุก request → แนบ `Authorization: Bearer <access_token>` header
2. ถ้าได้ 401 → เรียก `/auth/refresh` อัตโนมัติ
3. ถ้า refresh สำเร็จ → retry request เดิม
4. ถ้า refresh ล้มเหลว → clear tokens (user ต้อง login ใหม่)
5. concurrent 401s → serialize ด้วย `Completer` — refresh แค่ครั้งเดียว

---

## Routing & Auth Guard

`app_router.dart` ใช้ `GoRouter` + `redirect` callback:

| State | ผล |
| --- | --- |
| `AuthInitial` / `AuthLoading` | redirect → `/splash` |
| `AuthAuthenticated` | redirect → `/home` (ถ้าอยู่ที่ login/splash) |
| `AuthUnauthenticated` | redirect → `/login` |
| `AuthRegistered` | อยู่ที่ login flow ได้ (รอ login) |

---

## Case Study: เพิ่ม Feature ใหม่ "Chat"

ตัวอย่างนี้แสดงให้เห็นว่าต้องสร้างไฟล์อะไรบ้าง และทำไม ถ้าต้องการเพิ่ม feature **Chat** ให้ผู้ใช้คุยกันได้

### Step 1 — Domain Entities

**ไฟล์:** `lib/features/chat/domain/entities/message.dart`

**ทำไม:** Entity คือ "นิยาม" ของข้อมูลในโลก domain ไม่รู้จัก API ไม่รู้จัก JSON — รู้แค่ว่า Message มีอะไรบ้าง สร้างก่อนสุดเพราะไม่มี dependency ใดๆ

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';

enum MessageType { text, image, system }

@freezed
abstract class Message with _$Message {
  const Message._();

  const factory Message({
    required String id,
    required String roomId,
    required String senderId,
    required String content,
    required MessageType type,
    required DateTime sentAt,
    DateTime? readAt,
  }) = _Message;

  // Business logic อยู่ใน entity — ไม่อยู่ใน Widget
  bool get isRead => readAt != null;
  bool get isSystemMessage => type == MessageType.system;
}
```

```bash
# หลังสร้างไฟล์นี้ต้อง generate ก่อน ไฟล์อื่นถึงจะ import Message ได้
dart run build_runner build --delete-conflicting-outputs
```

---

### Step 2 — Repository Interface

**ไฟล์:** `lib/features/chat/domain/repositories/chat_repository.dart`

**ทำไม:** Interface บอกว่า domain ต้องการ operation อะไร โดยไม่สนใจว่า backend ใช้ WebSocket, REST หรือ gRPC — UseCase จะ depend บน interface นี้ ไม่ใช่ implementation ทำให้ mock ตอน test ง่าย

```dart
import 'package:fpdart/fpdart.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/chat/domain/entities/message.dart';

abstract class ChatRepository {
  // ดึงประวัติแชท (REST — paginated)
  Future<Either<Failure, List<Message>>> getMessages({
    required String roomId,
    String? before,
    int limit = 30,
  });

  // ส่งข้อความ
  Future<Either<Failure, Message>> sendMessage({
    required String roomId,
    required String content,
  });

  // Stream ข้อความใหม่แบบ real-time (WebSocket)
  Stream<Message> watchMessages(String roomId);
}
```

---

### Step 3 — UseCases (1 file ต่อ 1 operation)

**ทำไม:** Single Responsibility — BLoC ไม่ควร call repository โดยตรงเพราะจะ test ยากและ logic กระจาย ถ้าอยาก reuse logic ในหลาย BLoC ก็แค่ inject UseCase เดิม

**ไฟล์:** `lib/features/chat/domain/usecases/get_messages_usecase.dart`

```dart
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/chat/domain/entities/message.dart';
import 'package:ultra_sync/features/chat/domain/repositories/chat_repository.dart';

@lazySingleton
class GetMessagesUseCase implements UseCase<List<Message>, GetMessagesParams> {
  final ChatRepository _repository;
  const GetMessagesUseCase(this._repository);

  @override
  Future<Either<Failure, List<Message>>> call(GetMessagesParams params) =>
      _repository.getMessages(roomId: params.roomId, before: params.before);
}

class GetMessagesParams extends Equatable {
  final String roomId;
  final String? before;

  const GetMessagesParams({required this.roomId, this.before});

  @override
  List<Object?> get props => [roomId, before];
}
```

**ไฟล์:** `lib/features/chat/domain/usecases/send_message_usecase.dart`

```dart
@lazySingleton
class SendMessageUseCase implements UseCase<Message, SendMessageParams> {
  final ChatRepository _repository;
  const SendMessageUseCase(this._repository);

  @override
  Future<Either<Failure, Message>> call(SendMessageParams params) =>
      _repository.sendMessage(roomId: params.roomId, content: params.content);
}

class SendMessageParams extends Equatable {
  final String roomId;
  final String content;

  const SendMessageParams({required this.roomId, required this.content});

  @override
  List<Object?> get props => [roomId, content];
}
```

---

### Step 4 — Data Model

**ไฟล์:** `lib/features/chat/data/models/message_model.dart`

**ทำไม:** Model รู้จัก JSON format ของ API — แยกออกจาก Entity เพื่อให้ API เปลี่ยน field name ได้โดยไม่กระทบ domain เลย เช่น API ส่ง `sent_at` เป็น String แต่ Entity ใช้ `DateTime`

```dart
import 'package:ultra_sync/features/chat/domain/entities/message.dart';

class MessageModel {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final String type;      // API ส่งมาเป็น String เช่น "text"
  final String sentAt;    // API ส่งมาเป็น ISO8601 String
  final String? readAt;

  const MessageModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.sentAt,
    this.readAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'] as String,
        roomId: json['room_id'] as String,
        senderId: json['sender_id'] as String,
        content: json['content'] as String,
        type: json['type'] as String? ?? 'text',
        sentAt: json['sent_at'] as String,
        readAt: json['read_at'] as String?,
      );

  // แปลงเป็น domain entity — ทุก type conversion เกิดที่นี่
  Message toDomain() => Message(
        id: id,
        roomId: roomId,
        senderId: senderId,
        content: content,
        type: MessageType.values.byName(type),  // String → enum
        sentAt: DateTime.parse(sentAt),          // String → DateTime
        readAt: readAt != null ? DateTime.parse(readAt!) : null,
      );
}
```

---

### Step 5 — DataSource

**ไฟล์:** `lib/features/chat/data/datasources/chat_remote_data_source.dart`

**ทำไม:** DataSource พูดคุยกับ network โดยตรง — แยกออกมาให้ mock ได้ง่ายตอน test ไม่ต้องสั่ง network จริงๆ

```dart
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/network/api_client.dart';
import 'package:ultra_sync/features/chat/data/models/message_model.dart';

abstract class ChatRemoteDataSource {
  Future<List<MessageModel>> getMessages({required String roomId, String? before});
  Future<MessageModel> sendMessage({required String roomId, required String content});
}

@LazySingleton(as: ChatRemoteDataSource)
class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final ApiClient _client;
  ChatRemoteDataSourceImpl(this._client);

  @override
  Future<List<MessageModel>> getMessages({
    required String roomId,
    String? before,
  }) async {
    final response = await _client.dio.get(
      '/api/v1/chat/rooms/$roomId/messages',
      queryParameters: {if (before != null) 'before': before},
    );
    final body = response.data as Map<String, dynamic>;
    final items = body['data'] as List<dynamic>;
    return items
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MessageModel> sendMessage({
    required String roomId,
    required String content,
  }) async {
    final response = await _client.dio.post(
      '/api/v1/chat/rooms/$roomId/messages',
      data: {'content': content},
    );
    final body = response.data as Map<String, dynamic>;
    return MessageModel.fromJson(body['data'] as Map<String, dynamic>);
  }
}
```

---

### Step 6 — Repository Implementation

**ไฟล์:** `lib/features/chat/data/repositories/chat_repository_impl.dart`

**ทำไม:** Impl เชื่อม DataSource กับ Domain — ห่อ exception ให้เป็น `Either` และแปลง Model → Entity ทำให้ UseCase ไม่ต้องรู้จัก DioException เลย

```dart
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ultra_sync/features/chat/domain/entities/message.dart';
import 'package:ultra_sync/features/chat/domain/repositories/chat_repository.dart';

@LazySingleton(as: ChatRepository)
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remote;
  ChatRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<Message>>> getMessages({
    required String roomId,
    String? before,
    int limit = 30,
  }) async {
    try {
      final models = await _remote.getMessages(roomId: roomId, before: before);
      return Right(models.map((m) => m.toDomain()).toList());
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Message>> sendMessage({
    required String roomId,
    required String content,
  }) async {
    try {
      final model = await _remote.sendMessage(roomId: roomId, content: content);
      return Right(model.toDomain());
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(NetworkFailure());
    }
  }

  @override
  Stream<Message> watchMessages(String roomId) {
    // TODO: implement WebSocket stream
    throw UnimplementedError();
  }
}
```

---

### Step 7 — BLoC Events & States

**ไฟล์:** `lib/features/chat/presentation/bloc/chat_event.dart`

**ทำไม:** `sealed class` บังคับให้ switch exhaustive — ถ้าเพิ่ม event ใหม่แล้วลืม handle ใน BLoC จะ compile error ทันที

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ultra_sync/features/chat/domain/entities/message.dart';

part 'chat_event.freezed.dart';

@freezed
sealed class ChatEvent with _$ChatEvent {
  const factory ChatEvent.loadRequested({required String roomId}) = ChatLoadRequested;
  const factory ChatEvent.messageSent({required String content}) = ChatMessageSent;
  const factory ChatEvent.messageReceived(Message message) = ChatMessageReceived;
}
```

**ไฟล์:** `lib/features/chat/presentation/bloc/chat_state.dart`

**ทำไม:** State ต้อง immutable — `freezed` ให้ `copyWith` ฟรี ใช้ตอนอยาก update บางส่วนของ state

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ultra_sync/features/chat/domain/entities/message.dart';

part 'chat_state.freezed.dart';

@freezed
sealed class ChatState with _$ChatState {
  const factory ChatState.initial() = ChatInitial;
  const factory ChatState.loading() = ChatLoading;
  const factory ChatState.loaded({
    required String roomId,
    required List<Message> messages,
    @Default(false) bool isSending,   // UI แสดง spinner ที่ input box
  }) = ChatLoaded;
  const factory ChatState.error(String message) = ChatError;
}
```

```bash
# หลังสร้าง event.dart และ state.dart ต้อง generate ก่อน BLoC จะ compile ได้
dart run build_runner build --delete-conflicting-outputs
```

---

### Step 8 — BLoC

**ไฟล์:** `lib/features/chat/presentation/bloc/chat_bloc.dart`

**ทำไม:** BLoC คือ "สมอง" ของ feature — รับ Event → เรียก UseCase → emit State UI ไม่รู้จัก network ไม่รู้จัก repository รู้แค่ emit state

```dart
import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:ultra_sync/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_event.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_state.dart';

@injectable
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final GetMessagesUseCase _getMessages;
  final SendMessageUseCase _sendMessage;

  ChatBloc({
    required GetMessagesUseCase getMessages,
    required SendMessageUseCase sendMessage,
  })  : _getMessages = getMessages,
        _sendMessage = sendMessage,
        super(const ChatInitial()) {
    on<ChatLoadRequested>(_onLoad);
    on<ChatMessageSent>(_onSend);
    on<ChatMessageReceived>(_onReceived);
  }

  Future<void> _onLoad(ChatLoadRequested event, Emitter<ChatState> emit) async {
    emit(const ChatLoading());
    final result = await _getMessages(GetMessagesParams(roomId: event.roomId));
    result.fold(
      (failure) => emit(ChatError(failure.message)),
      (messages) => emit(ChatLoaded(roomId: event.roomId, messages: messages)),
    );
  }

  Future<void> _onSend(ChatMessageSent event, Emitter<ChatState> emit) async {
    final current = state;
    if (current is! ChatLoaded) return;

    emit(current.copyWith(isSending: true));  // copyWith มาจาก freezed — ไม่ต้องสร้าง object ใหม่ทั้งหมด
    final result = await _sendMessage(
      SendMessageParams(roomId: current.roomId, content: event.content),
    );
    result.fold(
      (failure) => emit(current.copyWith(isSending: false)),
      (message) => emit(current.copyWith(
        messages: [message, ...current.messages],  // prepend ข้อความใหม่
        isSending: false,
      )),
    );
  }

  void _onReceived(ChatMessageReceived event, Emitter<ChatState> emit) {
    final current = state;
    if (current is! ChatLoaded) return;
    // WebSocket push ข้อความใหม่เข้ามา — prepend เข้า list
    emit(current.copyWith(messages: [event.message, ...current.messages]));
  }
}
```

---

### Step 9 — Page

**ไฟล์:** `lib/features/chat/presentation/pages/chat_page.dart`

**ทำไม:** Page มีหน้าที่เดียว — แสดง state ที่ BLoC ส่งมา และส่ง event กลับ BLoC ห้ามมี business logic ใน `build()`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ultra_sync/core/di/injection.dart';
import 'package:ultra_sync/core/widgets/app_snack_bar.dart';
import 'package:ultra_sync/core/widgets/empty_state.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_event.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_state.dart';

class ChatPage extends StatelessWidget {
  final String roomId;
  const ChatPage({required this.roomId, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // สร้าง BLoC แล้ว dispatch event แรกทันที
      create: (_) => getIt<ChatBloc>()..add(ChatLoadRequested(roomId: roomId)),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      // listener = side effects เท่านั้น (snackbar, navigation, analytics)
      listener: (context, state) {
        if (state is ChatError) AppSnackBar.showError(context, state.message);
      },
      // builder = UI เท่านั้น ไม่มี if/else ซ้อนกัน
      builder: (context, state) => switch (state) {
        ChatLoading() => const Center(child: CircularProgressIndicator()),
        ChatLoaded(:final messages, :final isSending) => _ChatBody(
            messages: messages,
            isSending: isSending,
          ),
        ChatError(:final message) => EmptyState(
            icon: Icons.error_outline,
            message: message,
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
```

---

### Step 10 — Unit Test

**ไฟล์:** `test/features/chat/bloc/chat_bloc_test.dart`

**ทำไม:** Test ยืนยันว่า BLoC emit states ถูกต้อง — mock UseCase แทน network จริง ทำให้ test เร็ว (ไม่ต้องมี server) และ deterministic (ผลเดิมทุกครั้ง)

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/chat/domain/entities/message.dart';
import 'package:ultra_sync/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:ultra_sync/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_event.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_state.dart';

class _MockGetMessages extends Mock implements GetMessagesUseCase {}
class _MockSendMessage extends Mock implements SendMessageUseCase {}

void main() {
  late _MockGetMessages getMessages;
  late _MockSendMessage sendMessage;

  final tMessage = Message(
    id: 'msg-1',
    roomId: 'room-1',
    senderId: 'user-1',
    content: 'Hello!',
    type: MessageType.text,
    sentAt: DateTime(2024),
  );

  ChatBloc buildBloc() => ChatBloc(
        getMessages: getMessages,
        sendMessage: sendMessage,
      );

  setUp(() {
    getMessages = _MockGetMessages();
    sendMessage = _MockSendMessage();
    registerFallbackValue(const GetMessagesParams(roomId: ''));
    registerFallbackValue(const SendMessageParams(roomId: '', content: ''));
  });

  group('ChatLoadRequested', () {
    blocTest<ChatBloc, ChatState>(
      'emits [Loading, Loaded] on success',
      build: () {
        when(() => getMessages(any()))
            .thenAnswer((_) async => Right([tMessage]));
        return buildBloc();
      },
      act: (b) => b.add(const ChatLoadRequested(roomId: 'room-1')),
      expect: () => [
        const ChatLoading(),
        ChatLoaded(roomId: 'room-1', messages: [tMessage]),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'emits [Loading, Error] on network failure',
      build: () {
        when(() => getMessages(any()))
            .thenAnswer((_) async => const Left(NetworkFailure()));
        return buildBloc();
      },
      act: (b) => b.add(const ChatLoadRequested(roomId: 'room-1')),
      expect: () => [
        const ChatLoading(),
        const ChatError('No internet connection'),
      ],
    );
  });

  group('ChatMessageSent', () {
    blocTest<ChatBloc, ChatState>(
      'prepends new message to list on success',
      build: () {
        when(() => getMessages(any()))
            .thenAnswer((_) async => Right([tMessage]));
        when(() => sendMessage(any()))
            .thenAnswer((_) async => Right(tMessage));
        return buildBloc();
      },
      // โหลดก่อน แล้วส่งข้อความ
      act: (b) async {
        b.add(const ChatLoadRequested(roomId: 'room-1'));
        await Future<void>.delayed(Duration.zero);
        b.add(const ChatMessageSent(content: 'Hello!'));
      },
      expect: () => [
        const ChatLoading(),
        ChatLoaded(roomId: 'room-1', messages: [tMessage]),
        ChatLoaded(roomId: 'room-1', messages: [tMessage], isSending: true),
        ChatLoaded(roomId: 'room-1', messages: [tMessage, tMessage]),
      ],
    );
  });
}
```

---

### สรุปไฟล์ที่ต้องสร้างสำหรับ 1 feature ใหม่

```text
features/chat/
│
├── domain/                                    ← สร้างก่อน (ไม่มี dependency ภายนอก)
│   ├── entities/
│   │   ├── message.dart                       # 1. นิยาม data + business rules
│   │   └── message.freezed.dart              #    AUTO-GENERATED (run build_runner)
│   ├── repositories/
│   │   └── chat_repository.dart              # 2. interface — domain ต้องการอะไร
│   └── usecases/
│       ├── get_messages_usecase.dart         # 3. หนึ่ง operation = หนึ่งไฟล์
│       └── send_message_usecase.dart         # 4.
│
├── data/                                      ← สร้างหลัง domain
│   ├── models/
│   │   └── message_model.dart               # 5. JSON parsing + toDomain()
│   ├── datasources/
│   │   └── chat_remote_data_source.dart     # 6. Dio calls เท่านั้น — ไม่มี logic
│   └── repositories/
│       └── chat_repository_impl.dart        # 7. ห่อ exception → Either + call toDomain()
│
└── presentation/                              ← สร้างสุดท้าย
    ├── bloc/
    │   ├── chat_event.dart                   # 8. sealed events (freezed)
    │   ├── chat_event.freezed.dart          #    AUTO-GENERATED
    │   ├── chat_state.dart                   # 9. sealed states (freezed)
    │   ├── chat_state.freezed.dart          #    AUTO-GENERATED
    │   └── chat_bloc.dart                   # 10. Event → UseCase → State
    └── pages/
        └── chat_page.dart                   # 11. UI เท่านั้น — ไม่มี logic

test/features/chat/
└── bloc/
    └── chat_bloc_test.dart                  # 12. test BLoC ด้วย mock UseCase
```

> **ลำดับสำคัญมาก:** Domain → Data → Presentation
>
> เพราะ domain ไม่ขึ้นกับใคร → data ขึ้นกับ domain → presentation ขึ้นกับทั้งสอง
> ถ้าสร้างกลับด้านจะเกิด circular dependency compile error

---

## Shared Widgets

Widget ที่ใช้ร่วมกันทุก feature อยู่ใน `core/widgets/` — ห้าม copy-paste:

| Widget | ใช้แทน | ทำไม |
| --- | --- | --- |
| `AppButton` | `ElevatedButton` | มี gradient + loading spinner built-in |
| `AppTextField` | `TextFormField` | style เหมือนกันทุกที่ |
| `AppSnackBar.showError(context, msg)` | `ScaffoldMessenger.showSnackBar(...)` | centralize style + duration |
| `EmptyState(icon, message)` | custom column | ลด duplication |

---

## Extensions

```dart
// แทนที่ Theme.of(context).colorScheme.primary
context.colorScheme.primary

// แทนที่ MediaQuery.sizeOf(context).width
context.screenWidth

// แทนที่ GoRouter.of(context).push(...)
context.router.push('/chat/room-1')

// String utils
'hello world'.capitalize()      // 'Hello World'
'  '.nullIfEmpty                // null
'user@email.com'.isValidEmail   // true

// DateTime utils
DateTime.now().formatted        // '17 May 2026'
DateTime.now().dateOnly         // '2026-05-17'
```

---

## Code Generation

ไฟล์ที่มี `.freezed.dart` และ `injection.config.dart` ถูก **generate อัตโนมัติ** — ห้ามแก้มือ:

```bash
# ทุกครั้งที่แก้ไฟล์เหล่านี้:
# - @freezed class (entity, event, state)
# - @injectable / @lazySingleton annotation

dart run build_runner build --delete-conflicting-outputs
```

---

## Conventions

| หัวข้อ | กฎ |
| --- | --- |
| ชื่อไฟล์ | `snake_case.dart` เสมอ |
| ชื่อ class | `PascalCase` |
| ขนาดไฟล์ | ไม่เกิน 300 บรรทัด — ถ้าเกินให้ extract widget ย่อย |
| Business logic | ห้ามอยู่ใน `build()` method หรือ Widget |
| Repository / DataSource | ห้าม Widget รู้จักโดยตรง |
| CPU-heavy work | ต้องรันใน `Isolate` |
| Shared UI | ใช้ `core/widgets/` — ห้าม copy-paste |
