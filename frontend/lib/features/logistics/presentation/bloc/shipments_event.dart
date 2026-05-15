part of 'shipments_bloc.dart';

abstract class ShipmentsEvent extends Equatable {
  const ShipmentsEvent();

  @override
  List<Object?> get props => [];
}

class ShipmentsLoadRequested extends ShipmentsEvent {
  final String? status;
  const ShipmentsLoadRequested({this.status});

  @override
  List<Object?> get props => [status];
}

class ShipmentCreateRequested extends ShipmentsEvent {
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;

  const ShipmentCreateRequested({
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  @override
  List<Object?> get props => [pickupLat, pickupLng, dropoffLat, dropoffLng];
}

class ShipmentDetailRequested extends ShipmentsEvent {
  final String id;
  const ShipmentDetailRequested(this.id);

  @override
  List<Object?> get props => [id];
}
