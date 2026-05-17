import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/auth/domain/entities/user.dart';

part 'auth_state.freezed.dart';

@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated({required TokenPair tokens}) = AuthAuthenticated;
  const factory AuthState.registered({required User user}) = AuthRegistered;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.failure({required Failure failure}) = AuthFailureState;
}
