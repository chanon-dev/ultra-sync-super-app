part of 'shipments_bloc.dart';

abstract class ShipmentsState extends Equatable {
  const ShipmentsState();

  @override
  List<Object?> get props => [];
}

class ShipmentsInitial extends ShipmentsState {
  const ShipmentsInitial();
}

class ShipmentsLoading extends ShipmentsState {
  const ShipmentsLoading();
}

class ShipmentsLoaded extends ShipmentsState {
  final List<Shipment> shipments;
  const ShipmentsLoaded(this.shipments);

  @override
  List<Object?> get props => [shipments];
}

class ShipmentCreated extends ShipmentsState {
  final Shipment shipment;
  const ShipmentCreated(this.shipment);

  @override
  List<Object?> get props => [shipment];
}

class ShipmentDetail extends ShipmentsState {
  final Shipment shipment;
  const ShipmentDetail(this.shipment);

  @override
  List<Object?> get props => [shipment];
}

class ShipmentsError extends ShipmentsState {
  final String message;
  const ShipmentsError(this.message);

  @override
  List<Object?> get props => [message];
}
