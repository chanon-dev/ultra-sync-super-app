import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/logistics/data/datasources/shipment_remote_data_source.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';
import 'package:ultra_sync/features/logistics/domain/repositories/shipment_repository.dart';

@LazySingleton(as: ShipmentRepository)
class ShipmentRepositoryImpl implements ShipmentRepository {
  final ShipmentRemoteDataSource _remote;
  ShipmentRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, Shipment>> createShipment({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    try {
      final model = await _remote.createShipment(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );
      return Right(model.toDomain());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Shipment>>> listShipments({
    String? status,
    String? after,
    int limit = 20,
  }) async {
    try {
      final models = await _remote.listShipments(status: status, after: after, limit: limit);
      return Right(models.map((m) => m.toDomain()).toList());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Shipment>> getShipment(String id) async {
    try {
      final model = await _remote.getShipment(id);
      return Right(model.toDomain());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
