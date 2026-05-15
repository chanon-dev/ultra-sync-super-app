import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';
import 'package:ultra_sync/features/logistics/domain/repositories/shipment_repository.dart';

@lazySingleton
class ListShipmentsUseCase implements UseCase<List<Shipment>, ListShipmentsParams> {
  final ShipmentRepository _repository;
  const ListShipmentsUseCase(this._repository);

  @override
  Future<Either<Failure, List<Shipment>>> call(ListShipmentsParams params) {
    return _repository.listShipments(
      status: params.status,
      after: params.after,
      limit: params.limit,
    );
  }
}

class ListShipmentsParams extends Equatable {
  final String? status;
  final String? after;
  final int limit;

  const ListShipmentsParams({this.status, this.after, this.limit = 20});

  @override
  List<Object?> get props => [status, after, limit];
}
