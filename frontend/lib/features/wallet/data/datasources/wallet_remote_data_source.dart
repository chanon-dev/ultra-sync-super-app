import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/network/api_client.dart';
import 'package:ultra_sync/features/wallet/data/models/wallet_model.dart';

abstract class WalletRemoteDataSource {
  Future<WalletModel> getBalance();

  Future<TransactionModel> topUp({
    required String amount,
    required String idempotencyKey,
  });

  Future<List<TransactionModel>> listTransactions({
    String? type,
    String? after,
    int limit = 20,
  });
}

@LazySingleton(as: WalletRemoteDataSource)
class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  final ApiClient _client;

  WalletRemoteDataSourceImpl(this._client);

  @override
  Future<WalletModel> getBalance() async {
    try {
      final response = await _client.dio.get('/api/v1/wallet/balance');
      return WalletModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<TransactionModel> topUp({
    required String amount,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _client.dio.post(
        '/api/v1/wallet/topup',
        data: {'amount': amount},
        options: Options(headers: {'X-Idempotency-Key': idempotencyKey}),
      );
      return TransactionModel.fromJson(
          response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<List<TransactionModel>> listTransactions({
    String? type,
    String? after,
    int limit = 20,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit};
      if (type != null) params['type'] = type;
      if (after != null) params['after'] = after;

      final response = await _client.dio.get(
        '/api/v1/wallet/transactions',
        queryParameters: params,
      );

      final items = response.data['data'] as List<dynamic>;
      return items
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Failure _mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data as Map<String, dynamic>?;
    final error = body?['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String? ?? 'Unknown error';
    final code = error?['code'] as String? ?? 'WAL-001';

    return switch (statusCode) {
      400 => ValidationFailure(message: message, code: code),
      401 => const UnauthorizedFailure(),
      422 => ServerFailure(message: message, code: code),
      null => const NetworkFailure(),
      _ => ServerFailure(message: message, code: code),
    };
  }
}
