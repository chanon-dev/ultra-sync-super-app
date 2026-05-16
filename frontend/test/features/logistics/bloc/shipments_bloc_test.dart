import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/create_shipment_usecase.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/get_shipment_usecase.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/list_shipments_usecase.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_bloc.dart';

class _MockList extends Mock implements ListShipmentsUseCase {}
class _MockCreate extends Mock implements CreateShipmentUseCase {}
class _MockGet extends Mock implements GetShipmentUseCase {}

void main() {
  late _MockList list;
  late _MockCreate create;
  late _MockGet get;

  final tShipment = Shipment(
    id: 'ship-1',
    orderNo: 'ORD-2024-abc',
    senderId: 'user-1',
    status: ShipmentStatus.pending,
    pickupGeo: const GeoPoint(latitude: 13.7, longitude: 100.5),
    dropoffGeo: const GeoPoint(latitude: 13.8, longitude: 100.6),
    price: '0.0000',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  ShipmentsBloc buildBloc() => ShipmentsBloc(
        list: list,
        create: create,
        get: get,
      );

  setUp(() {
    list = _MockList();
    create = _MockCreate();
    get = _MockGet();
    registerFallbackValue(const ListShipmentsParams());
    registerFallbackValue(const CreateShipmentParams(
      pickupLat: 0,
      pickupLng: 0,
      dropoffLat: 0,
      dropoffLng: 0,
    ));
    registerFallbackValue('');
  });

  // ── ShipmentsLoadRequested ────────────────────────────────────────────────

  group('ShipmentsLoadRequested', () {
    blocTest<ShipmentsBloc, ShipmentsState>(
      'emits [Loading, Loaded] on success',
      build: () {
        when(() => list(any())).thenAnswer((_) async => Right([tShipment]));
        return buildBloc();
      },
      act: (b) => b.add(const ShipmentsLoadRequested()),
      expect: () => [
        const ShipmentsLoading(),
        ShipmentsLoaded([tShipment]),
      ],
    );

    blocTest<ShipmentsBloc, ShipmentsState>(
      'emits [Loading, Loaded] with empty list when no shipments',
      build: () {
        when(() => list(any())).thenAnswer((_) async => const Right([]));
        return buildBloc();
      },
      act: (b) => b.add(const ShipmentsLoadRequested()),
      expect: () => [
        const ShipmentsLoading(),
        const ShipmentsLoaded([]),
      ],
    );

    blocTest<ShipmentsBloc, ShipmentsState>(
      'emits [Loading, Error] when list fails',
      build: () {
        when(() => list(any()))
            .thenAnswer((_) async => const Left(NetworkFailure()));
        return buildBloc();
      },
      act: (b) => b.add(const ShipmentsLoadRequested()),
      expect: () => [
        const ShipmentsLoading(),
        const ShipmentsError('No internet connection'),
      ],
    );

    blocTest<ShipmentsBloc, ShipmentsState>(
      'filters by status when provided',
      build: () {
        when(() => list(any())).thenAnswer((_) async => Right([tShipment]));
        return buildBloc();
      },
      act: (b) => b.add(const ShipmentsLoadRequested(status: 'pending')),
      expect: () => [
        const ShipmentsLoading(),
        ShipmentsLoaded([tShipment]),
      ],
      verify: (_) {
        verify(() => list(const ListShipmentsParams(status: 'pending'))).called(1);
      },
    );
  });

  // ── ShipmentCreateRequested ───────────────────────────────────────────────

  group('ShipmentCreateRequested', () {
    blocTest<ShipmentsBloc, ShipmentsState>(
      'emits [Loading, Created] on success',
      build: () {
        when(() => create(any())).thenAnswer((_) async => Right(tShipment));
        return buildBloc();
      },
      act: (b) => b.add(const ShipmentCreateRequested(
        pickupLat: 13.7,
        pickupLng: 100.5,
        dropoffLat: 13.8,
        dropoffLng: 100.6,
      )),
      expect: () => [
        const ShipmentsLoading(),
        ShipmentCreated(tShipment),
      ],
    );

    blocTest<ShipmentsBloc, ShipmentsState>(
      'emits [Loading, Error] when create fails',
      build: () {
        when(() => create(any())).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'server error')),
        );
        return buildBloc();
      },
      act: (b) => b.add(const ShipmentCreateRequested(
        pickupLat: 0,
        pickupLng: 0,
        dropoffLat: 0,
        dropoffLng: 0,
      )),
      expect: () => [
        const ShipmentsLoading(),
        const ShipmentsError('server error'),
      ],
    );
  });

  // ── ShipmentDetailRequested ───────────────────────────────────────────────

  group('ShipmentDetailRequested', () {
    blocTest<ShipmentsBloc, ShipmentsState>(
      'emits [Loading, Detail] on success',
      build: () {
        when(() => get(any())).thenAnswer((_) async => Right(tShipment));
        return buildBloc();
      },
      act: (b) => b.add(const ShipmentDetailRequested('ship-1')),
      expect: () => [
        const ShipmentsLoading(),
        ShipmentDetail(tShipment),
      ],
    );

    blocTest<ShipmentsBloc, ShipmentsState>(
      'emits [Loading, Error] when shipment not found',
      build: () {
        when(() => get(any()))
            .thenAnswer((_) async => const Left(ServerFailure(message: 'not found')));
        return buildBloc();
      },
      act: (b) => b.add(const ShipmentDetailRequested('bad-id')),
      expect: () => [
        const ShipmentsLoading(),
        const ShipmentsError('not found'),
      ],
    );
  });
}
