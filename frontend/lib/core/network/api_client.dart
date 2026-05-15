import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  ApiClient({required String baseUrl, required FlutterSecureStorage storage})
      : _storage = storage {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(_AuthInterceptor(storage: _storage, dio: _dio));
  }

  Dio get dio => _dio;

  Future<void> saveTokens({required String access, required String refresh}) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: access),
      _storage.write(key: _refreshTokenKey, value: refresh),
    ]);
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage storage;
  final Dio dio;

  _AuthInterceptor({required this.storage, required this.dio});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        // Retry original request with new token
        final token = await storage.read(key: 'access_token');
        err.requestOptions.headers['Authorization'] = 'Bearer $token';
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      }
    }
    handler.next(err);
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await storage.read(key: 'refresh_token');
    if (refreshToken == null) return false;

    try {
      final response = await dio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = response.data['data'] as Map<String, dynamic>;
      await Future.wait([
        storage.write(key: 'access_token', value: data['access_token'] as String),
        storage.write(key: 'refresh_token', value: data['refresh_token'] as String),
      ]);
      return true;
    } catch (_) {
      await Future.wait([
        storage.delete(key: 'access_token'),
        storage.delete(key: 'refresh_token'),
      ]);
      return false;
    }
  }
}
