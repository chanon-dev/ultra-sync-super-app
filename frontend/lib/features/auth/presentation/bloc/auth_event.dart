part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String role;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    this.role = 'user',
  });

  @override
  List<Object?> get props => [email, password, role];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}
