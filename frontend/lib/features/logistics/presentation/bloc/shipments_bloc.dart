import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/create_shipment_usecase.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/get_shipment_usecase.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/list_shipments_usecase.dart';

part 'shipments_event.dart';
part 'shipments_state.dart';

@injectable
class ShipmentsBloc extends Bloc<ShipmentsEvent, ShipmentsState> {
  final ListShipmentsUseCase _list;
  final CreateShipmentUseCase _create;
  final GetShipmentUseCase _get;

  ShipmentsBloc({
    required ListShipmentsUseCase list,
    required CreateShipmentUseCase create,
    required GetShipmentUseCase get,
  })  : _list = list,
        _create = create,
        _get = get,
        super(const ShipmentsInitial()) {
    on<ShipmentsLoadRequested>(_onLoad);
    on<ShipmentCreateRequested>(_onCreate);
    on<ShipmentDetailRequested>(_onDetail);
  }

  Future<void> _onLoad(
    ShipmentsLoadRequested event,
    Emitter<ShipmentsState> emit,
  ) async {
    emit(const ShipmentsLoading());
    final result = await _list(ListShipmentsParams(status: event.status));
    result.fold(
      (f) => emit(ShipmentsError(f.message)),
      (shipments) => emit(ShipmentsLoaded(shipments)),
    );
  }

  Future<void> _onCreate(
    ShipmentCreateRequested event,
    Emitter<ShipmentsState> emit,
  ) async {
    emit(const ShipmentsLoading());
    final result = await _create(CreateShipmentParams(
      pickupLat: event.pickupLat,
      pickupLng: event.pickupLng,
      dropoffLat: event.dropoffLat,
      dropoffLng: event.dropoffLng,
    ));
    result.fold(
      (f) => emit(ShipmentsError(f.message)),
      (shipment) => emit(ShipmentCreated(shipment)),
    );
  }

  Future<void> _onDetail(
    ShipmentDetailRequested event,
    Emitter<ShipmentsState> emit,
  ) async {
    emit(const ShipmentsLoading());
    final result = await _get(event.id);
    result.fold(
      (f) => emit(ShipmentsError(f.message)),
      (shipment) => emit(ShipmentDetail(shipment)),
    );
  }
}
