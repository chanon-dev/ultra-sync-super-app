import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';

part 'shipments_event.freezed.dart';

@freezed
sealed class ShipmentsEvent with _$ShipmentsEvent {
  const factory ShipmentsEvent.loadRequested({String? status}) = ShipmentsLoadRequested;

  const factory ShipmentsEvent.createRequested({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) = ShipmentCreateRequested;

  const factory ShipmentsEvent.detailRequested(String id) = ShipmentDetailRequested;

  const factory ShipmentsEvent.filterChanged(ShipmentStatus? filter) = ShipmentsFilterChanged;

  const factory ShipmentsEvent.searchChanged(String query) = ShipmentsSearchChanged;
}
