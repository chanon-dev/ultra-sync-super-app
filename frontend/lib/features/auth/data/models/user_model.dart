import 'package:ultra_sync/features/auth/domain/entities/user.dart';

class UserModel {
  final String id;
  final String email;
  final String role;
  final String status;

  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['user_id'] as String,
        email: json['email'] as String,
        role: json['role'] as String? ?? 'user',
        status: json['status'] as String? ?? 'pending_verify',
      );

  User toDomain() => User(id: id, email: email, role: role, status: status);

  Map<String, dynamic> toJson() => {
        'user_id': id,
        'email': email,
        'role': role,
        'status': status,
      };
}

class TokenPairModel {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  const TokenPairModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory TokenPairModel.fromJson(Map<String, dynamic> json) => TokenPairModel(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresIn: json['expires_in'] as int? ?? 900,
      );

  TokenPair toDomain() => TokenPair(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
      );
}
