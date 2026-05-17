import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:rxdart/rxdart.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/create_shipment_usecase.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/get_shipment_usecase.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/list_shipments_usecase.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_event.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_state.dart';

EventTransformer<E> _debounce<E>(Duration duration) =>
    (events, mapper) => events.debounceTime(duration).switchMap(mapper);

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
    on<ShipmentsFilterChanged>(_onFilterChanged);
    on<ShipmentsSearchChanged>(
      _onSearchChanged,
      transformer: _debounce(const Duration(milliseconds: 300)),
    );
  }

  Future<void> _onLoad(
    ShipmentsLoadRequested event,
    Emitter<ShipmentsState> emit,
  ) async {
    emit(const ShipmentsLoading());
    final result = await _list(ListShipmentsParams(status: event.status));
    result.fold(
      (f) => emit(ShipmentsError(f.message)),
      (shipments) => emit(ShipmentsLoaded(all: shipments, filtered: shipments)),
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

  void _onFilterChanged(
    ShipmentsFilterChanged event,
    Emitter<ShipmentsState> emit,
  ) {
    if (state is! ShipmentsLoaded) return;
    final current = state as ShipmentsLoaded;
    emit(current.copyWith(
      activeFilter: event.filter,
      filtered: _applyFilter(current.all, event.filter, current.query),
    ));
  }

  Future<void> _onSearchChanged(
    ShipmentsSearchChanged event,
    Emitter<ShipmentsState> emit,
  ) async {
    if (state is! ShipmentsLoaded) return;
    final current = state as ShipmentsLoaded;
    emit(current.copyWith(
      query: event.query,
      filtered: _applyFilter(current.all, current.activeFilter, event.query),
    ));
  }

  List<Shipment> _applyFilter(
    List<Shipment> all,
    ShipmentStatus? filter,
    String query,
  ) {
    var list = filter == null ? all : all.where((s) => s.status == filter).toList();
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((s) => s.orderNo.toLowerCase().contains(q)).toList();
    }
    return list;
  }
}
