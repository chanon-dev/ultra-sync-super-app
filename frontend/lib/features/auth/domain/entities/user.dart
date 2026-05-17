import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

@freezed
abstract class User with _$User {
  const User._();

  const factory User({
    required String id,
    required String email,
    required String role,
    required String status,
  }) = _User;

  bool get isActive => status == 'active';
  bool get isDriver => role == 'driver';
  bool get isAdmin => role == 'admin';
}

@freezed
abstract class TokenPair with _$TokenPair {
  const factory TokenPair({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) = _TokenPair;
}
