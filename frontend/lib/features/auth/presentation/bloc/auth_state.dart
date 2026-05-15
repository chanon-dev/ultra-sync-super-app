part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final TokenPair tokens;

  const AuthAuthenticated({required this.tokens});

  @override
  List<Object?> get props => [tokens];
}

class AuthRegistered extends AuthState {
  final User user;

  const AuthRegistered({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthFailureState extends AuthState {
  final Failure failure;

  const AuthFailureState({required this.failure});

  @override
  List<Object?> get props => [failure];
}
