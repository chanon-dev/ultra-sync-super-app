import 'package:equatable/equatable.dart';

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

class GeoPoint extends Equatable {
  final double latitude;
  final double longitude;

  const GeoPoint({required this.latitude, required this.longitude});

  @override
  List<Object?> get props => [latitude, longitude];
}

class Shipment extends Equatable {
  final String id;
  final String orderNo;
  final String senderId;
  final String? driverId;
  final ShipmentStatus status;
  final GeoPoint pickupGeo;
  final GeoPoint dropoffGeo;
  final String price;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Shipment({
    required this.id,
    required this.orderNo,
    required this.senderId,
    this.driverId,
    required this.status,
    required this.pickupGeo,
    required this.dropoffGeo,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive =>
      status == ShipmentStatus.assigned ||
      status == ShipmentStatus.pickedUp ||
      status == ShipmentStatus.shipping;

  @override
  List<Object?> get props => [id, orderNo, status, updatedAt];
}
