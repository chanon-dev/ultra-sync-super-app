import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';

part 'shipments_state.freezed.dart';

@freezed
sealed class ShipmentsState with _$ShipmentsState {
  const factory ShipmentsState.initial() = ShipmentsInitial;
  const factory ShipmentsState.loading() = ShipmentsLoading;
  const factory ShipmentsState.loaded({
    required List<Shipment> all,
    required List<Shipment> filtered,
    // null means "All" selected.
    ShipmentStatus? activeFilter,
    @Default('') String query,
  }) = ShipmentsLoaded;
  const factory ShipmentsState.created(Shipment shipment) = ShipmentCreated;
  const factory ShipmentsState.detail(Shipment shipment) = ShipmentDetail;
  const factory ShipmentsState.error(String message) = ShipmentsError;
}
