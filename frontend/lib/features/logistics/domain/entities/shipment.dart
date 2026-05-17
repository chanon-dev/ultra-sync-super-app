import 'package:freezed_annotation/freezed_annotation.dart';

part 'shipment.freezed.dart';

enum ShipmentStatus {
  pending,
  assigned,
  pickedUp,
  shipping,
  delivered,
  cancelled;

  String get label => switch (this) {
        pending => 'Pending',
        assigned => 'Assigned',
        pickedUp => 'Picked Up',
        shipping => 'Shipping',
        delivered => 'Delivered',
        cancelled => 'Cancelled',
      };

  static ShipmentStatus fromString(String s) => switch (s) {
        'assigned' => assigned,
        'picked_up' => pickedUp,
        'shipping' => shipping,
        'delivered' => delivered,
        'cancelled' => cancelled,
        _ => pending,
      };
}

@freezed
abstract class GeoPoint with _$GeoPoint {
  const factory GeoPoint({
    required double latitude,
    required double longitude,
  }) = _GeoPoint;
}

@freezed
abstract class Shipment with _$Shipment {
  const Shipment._();

  const factory Shipment({
    required String id,
    required String orderNo,
    required String senderId,
    String? driverId,
    required ShipmentStatus status,
    required GeoPoint pickupGeo,
    required GeoPoint dropoffGeo,
    required String price,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Shipment;

  bool get isActive =>
      status == ShipmentStatus.assigned ||
      status == ShipmentStatus.pickedUp ||
      status == ShipmentStatus.shipping;
}
