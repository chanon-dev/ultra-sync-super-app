import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';
import 'package:ultra_sync/features/logistics/domain/repositories/shipment_repository.dart';

@lazySingleton
class CreateShipmentUseCase implements UseCase<Shipment, CreateShipmentParams> {
  final ShipmentRepository _repository;
  const CreateShipmentUseCase(this._repository);

  @override
  Future<Either<Failure, Shipment>> call(CreateShipmentParams params) {
    return _repository.createShipment(
      pickupLat: params.pickupLat,
      pickupLng: params.pickupLng,
      dropoffLat: params.dropoffLat,
      dropoffLng: params.dropoffLng,
    );
  }
}

class CreateShipmentParams extends Equatable {
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;

  const CreateShipmentParams({
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  @override
  List<Object?> get props => [pickupLat, pickupLng, dropoffLat, dropoffLng];
}
