import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';

class GeoPointModel {
  final double latitude;
  final double longitude;

  const GeoPointModel({required this.latitude, required this.longitude});

  factory GeoPointModel.fromJson(Map<String, dynamic> json) => GeoPointModel(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
      );

  GeoPoint toDomain() => GeoPoint(latitude: latitude, longitude: longitude);
}

class ShipmentModel {
  final String id;
  final String orderNo;
  final String senderId;
  final String? driverId;
  final ShipmentStatus status;
  final GeoPointModel pickupGeo;
  final GeoPointModel dropoffGeo;
  final String price;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShipmentModel({
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

  factory ShipmentModel.fromJson(Map<String, dynamic> json) => ShipmentModel(
        id: json['id'] as String,
        orderNo: json['order_no'] as String,
        senderId: json['sender_id'] as String,
        driverId: json['driver_id'] as String?,
        status: ShipmentStatus.fromString(json['status'] as String? ?? 'pending'),
        pickupGeo: GeoPointModel(
          latitude: (json['pickup_lat'] as num).toDouble(),
          longitude: (json['pickup_lng'] as num).toDouble(),
        ),
        dropoffGeo: GeoPointModel(
          latitude: (json['dropoff_lat'] as num).toDouble(),
          longitude: (json['dropoff_lng'] as num).toDouble(),
        ),
        price: json['price'] as String? ?? '0.0000',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Shipment toDomain() => Shipment(
        id: id,
        orderNo: orderNo,
        senderId: senderId,
        driverId: driverId,
        status: status,
        pickupGeo: pickupGeo.toDomain(),
        dropoffGeo: dropoffGeo.toDomain(),
        price: price,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
