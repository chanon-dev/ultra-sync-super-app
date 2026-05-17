import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/network/api_client.dart';
import 'package:ultra_sync/features/logistics/data/models/shipment_model.dart';

abstract class ShipmentRemoteDataSource {
  Future<ShipmentModel> createShipment({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  });

  Future<List<ShipmentModel>> listShipments({
    String? status,
    String? after,
    int limit = 20,
  });

  Future<ShipmentModel> getShipment(String id);
}

@LazySingleton(as: ShipmentRemoteDataSource)
class ShipmentRemoteDataSourceImpl implements ShipmentRemoteDataSource {
  final ApiClient _client;
  ShipmentRemoteDataSourceImpl(this._client);

  @override
  Future<ShipmentModel> createShipment({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    try {
      final response = await _client.dio.post(
        '/api/v1/shipments',
        data: {
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
        },
      );
      final body = response.data as Map<String, dynamic>;
      return ShipmentModel.fromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<List<ShipmentModel>> listShipments({
    String? status,
    String? after,
    int limit = 20,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit};
      if (status != null) params['status'] = status;
      if (after != null) params['after'] = after;

      final response = await _client.dio.get(
        '/api/v1/shipments',
        queryParameters: params,
      );

      final body = response.data as Map<String, dynamic>;
      final items = body['data'] as List<dynamic>;
      return items
          .map((e) => ShipmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<ShipmentModel> getShipment(String id) async {
    try {
      final response = await _client.dio.get('/api/v1/shipments/$id');
      final body = response.data as Map<String, dynamic>;
      return ShipmentModel.fromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Failure _mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data as Map<String, dynamic>?;
    final error = body?['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String? ?? 'Unknown error';
    final code = error?['code'] as String? ?? 'LOG-001';

    return switch (statusCode) {
      400 => ValidationFailure(message: message, code: code),
      401 => const UnauthorizedFailure(),
      404 => const ServerFailure(message: 'Shipment not found', code: 'LOG-404'),
      null => const NetworkFailure(),
      _ => ServerFailure(message: message, code: code),
    };
  }
}
