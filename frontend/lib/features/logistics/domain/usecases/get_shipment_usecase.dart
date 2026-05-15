import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';
import 'package:ultra_sync/features/logistics/domain/repositories/shipment_repository.dart';

@lazySingleton
class GetShipmentUseCase implements UseCase<Shipment, String> {
  final ShipmentRepository _repository;
  const GetShipmentUseCase(this._repository);

  @override
  Future<Either<Failure, Shipment>> call(String id) {
    return _repository.getShipment(id);
  }
}
