import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String role;
  final String status;

  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
  });

  bool get isActive => status == 'active';
  bool get isDriver => role == 'driver';
  bool get isAdmin => role == 'admin';

  @override
  List<Object?> get props => [id, email, role, status];
}

class TokenPair extends Equatable {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresIn];
}
