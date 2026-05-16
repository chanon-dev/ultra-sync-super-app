import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_bloc.dart';

// Set MAPS_API_KEY in .env (local) or pass --dart-define=MAPS_API_KEY=<key> (CI/prod).
String get _mapsApiKey =>
    dotenv.env['MAPS_API_KEY'] ??
    const String.fromEnvironment('MAPS_API_KEY');

class TrackingPage extends StatefulWidget {
  final String shipmentId;
  const TrackingPage({super.key, required this.shipmentId});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Poll every 5 seconds for driver location updates.
    // Upgrade to SSE/WebSocket for true real-time: GET /api/v1/shipments/:id/track
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  void _load() {
    context
        .read<ShipmentsBloc>()
        .add(ShipmentDetailRequested(widget.shipmentId));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _LiveBadge(),
          ),
        ],
      ),
      body: BlocBuilder<ShipmentsBloc, ShipmentsState>(
        builder: (context, state) {
          if (state is ShipmentsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is ShipmentDetail) {
            return _TrackingContent(shipment: state.shipment);
          }
          if (state is ShipmentsError) {
            return Center(
              child: Text(state.message,
                  style: const TextStyle(color: AppColors.error)),
            );
          }
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        },
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _controller,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'LIVE',
          style: TextStyle(
            color: AppColors.secondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _TrackingContent extends StatelessWidget {
  final Shipment shipment;
  const _TrackingContent({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderHeader(shipment: shipment),
          const SizedBox(height: 20),
          _MapPlaceholder(shipment: shipment),
          const SizedBox(height: 20),
          _RouteCard(shipment: shipment),
          const SizedBox(height: 20),
          _StatusTimeline(status: shipment.status),
        ],
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  final Shipment shipment;
  const _OrderHeader({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shipment.orderNo,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.onBackground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                shipment.driverId != null
                    ? 'Driver assigned'
                    : 'Awaiting driver',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurface,
                    ),
              ),
            ],
          ),
        ),
        _StatusChip(shipment.status),
      ],
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final Shipment shipment;
  const _MapPlaceholder({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: _mapsApiKey.isNotEmpty
            ? _LiveMap(shipment: shipment)
            : _MapFallback(shipment: shipment),
      ),
    );
  }
}

class _LiveMap extends StatefulWidget {
  final Shipment shipment;
  const _LiveMap({required this.shipment});

  @override
  State<_LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<_LiveMap> {
  GoogleMapController? _controller;

  Set<Marker> get _markers => {
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(
            widget.shipment.pickupGeo.latitude,
            widget.shipment.pickupGeo.longitude,
          ),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(
            widget.shipment.dropoffGeo.latitude,
            widget.shipment.dropoffGeo.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Dropoff'),
        ),
      };

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.shipment.pickupGeo;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(pickup.latitude, pickup.longitude),
        zoom: 13,
      ),
      markers: _markers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: (c) => _controller = c,
    );
  }
}

class _MapFallback extends StatelessWidget {
  final Shipment shipment;
  const _MapFallback({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined,
                    color: AppColors.onSurface, size: 48),
                const SizedBox(height: 8),
                Text(
                  'Google Maps',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Build with --dart-define=MAPS_API_KEY=<key>',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurface,
                      ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _GeoTag(
              icon: Icons.my_location_rounded,
              color: AppColors.primary,
              geo: shipment.pickupGeo,
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: _GeoTag(
              icon: Icons.location_on_rounded,
              color: AppColors.error,
              geo: shipment.dropoffGeo,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeoTag extends StatelessWidget {
  final IconData icon;
  final Color color;
  final GeoPoint geo;
  const _GeoTag({required this.icon, required this.color, required this.geo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            '${geo.latitude.toStringAsFixed(3)}, ${geo.longitude.toStringAsFixed(3)}',
            style: const TextStyle(
                color: AppColors.onBackground,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final Shipment shipment;
  const _RouteCard({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _RouteStop(
            icon: Icons.my_location_rounded,
            color: AppColors.primary,
            label: 'Pickup',
            geo: shipment.pickupGeo,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 24,
                  color: AppColors.onSurface.withOpacity(0.2),
                ),
              ],
            ),
          ),
          _RouteStop(
            icon: Icons.location_on_rounded,
            color: AppColors.error,
            label: 'Dropoff',
            geo: shipment.dropoffGeo,
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final GeoPoint geo;
  const _RouteStop({
    required this.icon,
    required this.color,
    required this.label,
    required this.geo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.onSurface)),
              Text(
                '${geo.latitude.toStringAsFixed(6)}, ${geo.longitude.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onBackground,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final ShipmentStatus status;
  const _StatusTimeline({required this.status});

  static const _steps = [
    ShipmentStatus.pending,
    ShipmentStatus.assigned,
    ShipmentStatus.pickedUp,
    ShipmentStatus.shipping,
    ShipmentStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _steps.indexOf(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Progress',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_steps.length, (i) {
            final step = _steps[i];
            final isDone = currentIdx >= i;
            final isActive = currentIdx == i;
            return _TimelineStep(
              label: step.label,
              isDone: isDone,
              isActive: isActive,
              isLast: i == _steps.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isActive;
  final bool isLast;
  const _TimelineStep({
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone ? AppColors.secondary : AppColors.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isDone ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
                shape: BoxShape.circle,
              ),
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: isDone
                    ? AppColors.secondary.withOpacity(0.4)
                    : AppColors.onSurface.withOpacity(0.2),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.secondary : color,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ShipmentStatus status;
  const _StatusChip(this.status);

  Color get _color => switch (status) {
        ShipmentStatus.pending => AppColors.warning,
        ShipmentStatus.assigned || ShipmentStatus.pickedUp => AppColors.primary,
        ShipmentStatus.shipping => AppColors.secondary,
        ShipmentStatus.delivered => AppColors.secondary,
        ShipmentStatus.cancelled => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            color: _color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
