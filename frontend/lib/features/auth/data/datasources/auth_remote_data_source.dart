import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/network/api_client.dart';
import 'package:ultra_sync/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> register({
    required String email,
    required String password,
    required String role,
  });

  Future<TokenPairModel> login({
    required String email,
    required String password,
  });

  Future<TokenPairModel> refreshToken(String refreshToken);

  Future<void> logout(String refreshToken);
}

@LazySingleton(as: AuthRemoteDataSource)
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _client;

  AuthRemoteDataSourceImpl(this._client);

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final response = await _client.dio.post(
        '/api/v1/auth/register',
        data: {'email': email, 'password': password, 'role': role},
      );
      return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<TokenPairModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      return TokenPairModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<TokenPairModel> refreshToken(String refreshToken) async {
    try {
      final response = await _client.dio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return TokenPairModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _client.dio.post(
        '/api/v1/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Failure _mapDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data as Map<String, dynamic>?;
    final error = body?['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String? ?? 'Unknown error';
    final code = error?['code'] as String? ?? 'SRV-001';

    return switch (statusCode) {
      400 => ValidationFailure(message: message, code: code),
      401 => UnauthorizedFailure(message: message),
      null => const NetworkFailure(),
      _ => ServerFailure(message: message, code: code),
    };
  }
}
