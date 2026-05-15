import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/auth/domain/entities/user.dart';
import 'package:ultra_sync/features/auth/domain/usecases/login_usecase.dart';
import 'package:ultra_sync/features/auth/domain/usecases/register_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _login;
  final RegisterUseCase _register;

  AuthBloc({
    required LoginUseCase login,
    required RegisterUseCase register,
  })  : _login = login,
        _register = register,
        super(const AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onCheckRequested);
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
    emit(const AuthUnauthenticated());
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Phase 2: check secure storage for existing tokens
    emit(const AuthUnauthenticated());
  }
}
