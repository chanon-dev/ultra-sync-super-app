import 'package:fpdart/fpdart.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';

abstract class ShipmentRepository {
  Future<Either<Failure, Shipment>> createShipment({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  });

  Future<Either<Failure, List<Shipment>>> listShipments({
    String? status,
    String? after,
    int limit = 20,
  });

  Future<Either<Failure, Shipment>> getShipment(String id);
}
