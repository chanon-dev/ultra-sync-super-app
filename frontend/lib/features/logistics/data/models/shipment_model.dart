import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';

class GeoPointModel extends GeoPoint {
  const GeoPointModel({required super.latitude, required super.longitude});

  factory GeoPointModel.fromJson(Map<String, dynamic> json) => GeoPointModel(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
      );
}

class ShipmentModel extends Shipment {
  const ShipmentModel({
    required super.id,
    required super.orderNo,
    required super.senderId,
    super.driverId,
    required super.status,
    required super.pickupGeo,
    required super.dropoffGeo,
    required super.price,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    return ShipmentModel(
      id: json['id'] as String,
      orderNo: json['order_no'] as String,
      senderId: json['sender_id'] as String,
      driverId: json['driver_id'] as String?,
      status: ShipmentStatus.fromString(json['status'] as String? ?? 'pending'),
      pickupGeo: GeoPoint(
        latitude: (json['pickup_lat'] as num).toDouble(),
        longitude: (json['pickup_lng'] as num).toDouble(),
      ),
      dropoffGeo: GeoPoint(
        latitude: (json['dropoff_lat'] as num).toDouble(),
        longitude: (json['dropoff_lng'] as num).toDouble(),
      ),
      price: json['price'] as String? ?? '0.0000',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
