import 'package:ultra_sync/features/auth/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.role,
    required super.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['user_id'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'user',
      status: json['status'] as String? ?? 'pending_verify',
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': id,
        'email': email,
        'role': role,
        'status': status,
      };
}

class TokenPairModel extends TokenPair {
  const TokenPairModel({
    required super.accessToken,
    required super.refreshToken,
    required super.expiresIn,
  });

  factory TokenPairModel.fromJson(Map<String, dynamic> json) {
    return TokenPairModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int? ?? 900,
    );
  }
}
