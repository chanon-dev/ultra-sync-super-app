import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/services/biometric_service.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/auth/domain/entities/user.dart';
import 'package:ultra_sync/features/auth/domain/usecases/check_auth_usecase.dart';
import 'package:ultra_sync/features/auth/domain/usecases/login_usecase.dart';
import 'package:ultra_sync/features/auth/domain/usecases/logout_usecase.dart';
import 'package:ultra_sync/features/auth/domain/usecases/register_usecase.dart';
import 'package:ultra_sync/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ultra_sync/features/auth/presentation/bloc/auth_event.dart';
import 'package:ultra_sync/features/auth/presentation/bloc/auth_state.dart';

class _MockLogin extends Mock implements LoginUseCase {}
class _MockRegister extends Mock implements RegisterUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}
class _MockCheckAuth extends Mock implements CheckAuthUseCase {}
class _MockBiometricService extends Mock implements BiometricService {}

void main() {
  late _MockLogin login;
  late _MockRegister register;
  late _MockLogout logout;
  late _MockCheckAuth checkAuth;
  late _MockBiometricService biometrics;

  const tTokens = TokenPair(
    accessToken: 'access-tok',
    refreshToken: 'refresh-tok',
    expiresIn: 900,
  );

  const tUser = User(
    id: 'user-1',
    email: 'test@example.com',
    role: 'user',
    status: 'active',
  );

  AuthBloc buildBloc() => AuthBloc(
        login: login,
        register: register,
        logout: logout,
        checkAuth: checkAuth,
        biometrics: biometrics,
      );

  setUp(() {
    login = _MockLogin();
    register = _MockRegister();
    logout = _MockLogout();
    checkAuth = _MockCheckAuth();
    biometrics = _MockBiometricService();
    registerFallbackValue(const LoginParams(email: '', password: ''));
    registerFallbackValue(const RegisterParams(email: '', password: ''));
    registerFallbackValue(const NoParams());
  });

  // ── AuthLoginRequested ────────────────────────────────────────────────────

  group('AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Authenticated] on success',
      build: () {
        when(() => login(any())).thenAnswer((_) async => const Right(tTokens));
        return buildBloc();
      },
      act: (b) => b.add(const AuthLoginRequested(
        email: 'test@example.com',
        password: 'password',
      )),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(tokens: tTokens),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Failure] on login error',
      build: () {
        when(() => login(any())).thenAnswer(
          (_) async => const Left(UnauthorizedFailure()),
        );
        return buildBloc();
      },
      act: (b) => b.add(const AuthLoginRequested(
        email: 'bad@example.com',
        password: 'wrong',
      )),
      expect: () => [
        const AuthLoading(),
        isA<AuthFailureState>(),
      ],
    );
  });

  // ── AuthRegisterRequested ─────────────────────────────────────────────────

  group('AuthRegisterRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Registered] on success',
      build: () {
        when(() => register(any())).thenAnswer((_) async => const Right(tUser));
        return buildBloc();
      },
      act: (b) => b.add(const AuthRegisterRequested(
        email: 'new@example.com',
        password: 'pass123',
      )),
      expect: () => [
        const AuthLoading(),
        const AuthRegistered(user: tUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Failure] when email taken',
      build: () {
        when(() => register(any())).thenAnswer(
          (_) async => const Left(ValidationFailure(message: 'email already registered')),
        );
        return buildBloc();
      },
      act: (b) => b.add(const AuthRegisterRequested(
        email: 'taken@example.com',
        password: 'pass',
      )),
      expect: () => [
        const AuthLoading(),
        isA<AuthFailureState>(),
      ],
    );
  });

  // ── AuthLogoutRequested ───────────────────────────────────────────────────

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [Unauthenticated] after logout',
      build: () {
        when(() => logout(any()))
            .thenAnswer((_) async => const Right(unit));
        return buildBloc();
      },
      act: (b) => b.add(const AuthLogoutRequested()),
      expect: () => [const AuthUnauthenticated()],
    );
  });

  // ── AuthCheckRequested ────────────────────────────────────────────────────

  group('AuthCheckRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Authenticated] when token valid',
      build: () {
        when(() => checkAuth(any())).thenAnswer((_) async => const Right(tTokens));
        return buildBloc();
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(tokens: tTokens),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Unauthenticated] when no valid token',
      build: () {
        when(() => checkAuth(any()))
            .thenAnswer((_) async => const Left(UnauthorizedFailure()));
        return buildBloc();
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
    );
  });

  // ── AuthBiometricRequested ────────────────────────────────────────────────

  group('AuthBiometricRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Authenticated] when biometrics pass and token valid',
      build: () {
        when(() => biometrics.authenticate()).thenAnswer((_) async => true);
        when(() => checkAuth(any())).thenAnswer((_) async => const Right(tTokens));
        return buildBloc();
      },
      act: (b) => b.add(const AuthBiometricRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(tokens: tTokens),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits nothing when biometrics rejected',
      build: () {
        when(() => biometrics.authenticate()).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (b) => b.add(const AuthBiometricRequested()),
      expect: () => [],
    );
  });
}
