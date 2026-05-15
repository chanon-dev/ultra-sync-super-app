import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/services/biometric_service.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/auth/domain/entities/user.dart';
import 'package:ultra_sync/features/auth/domain/usecases/check_auth_usecase.dart';
import 'package:ultra_sync/features/auth/domain/usecases/login_usecase.dart';
import 'package:ultra_sync/features/auth/domain/usecases/logout_usecase.dart';
import 'package:ultra_sync/features/auth/domain/usecases/register_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _login;
  final RegisterUseCase _register;
  final LogoutUseCase _logout;
  final CheckAuthUseCase _checkAuth;
  final BiometricService _biometrics;

  AuthBloc({
    required LoginUseCase login,
    required RegisterUseCase register,
    required LogoutUseCase logout,
    required CheckAuthUseCase checkAuth,
    required BiometricService biometrics,
  })  : _login = login,
        _register = register,
        _logout = logout,
        _checkAuth = checkAuth,
        _biometrics = biometrics,
        super(const AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthBiometricRequested>(_onBiometricRequested);
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _login(LoginParams(
      email: event.email,
      password: event.password,
    ));
    result.fold(
      (failure) => emit(AuthFailureState(failure: failure)),
      (tokens) => emit(AuthAuthenticated(tokens: tokens)),
    );
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _register(RegisterParams(
      email: event.email,
      password: event.password,
      role: event.role,
    ));
    result.fold(
      (failure) => emit(AuthFailureState(failure: failure)),
      (user) => emit(AuthRegistered(user: user)),
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _logout(const NoParams());
    emit(const AuthUnauthenticated());
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _checkAuth(const NoParams());
    result.fold(
      (_) => emit(const AuthUnauthenticated()),
      (tokens) => emit(AuthAuthenticated(tokens: tokens)),
    );
  }

  Future<void> _onBiometricRequested(
    AuthBiometricRequested event,
    Emitter<AuthState> emit,
  ) async {
    final authenticated = await _biometrics.authenticate();
    if (!authenticated) return;

    emit(const AuthLoading());
    final result = await _checkAuth(const NoParams());
    result.fold(
      (_) => emit(const AuthUnauthenticated()),
      (tokens) => emit(AuthAuthenticated(tokens: tokens)),
    );
  }
}
