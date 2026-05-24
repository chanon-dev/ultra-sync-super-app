import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_bloc.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_event.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_state.dart';

// Set MAPS_API_KEY in .env (local) or pass --dart-define=MAPS_API_KEY=<key> (CI/prod).
String get _mapsApiKey =>
    dotenv.env['MAPS_API_KEY'] ?? const String.fromEnvironment('MAPS_API_KEY');

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

  void _load() =>
      context.read<ShipmentsBloc>().add(ShipmentDetailRequested(widget.shipmentId));

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
            return _TrackingBody(shipment: state.shipment);
          }
          if (state is ShipmentsError) {
            return _ErrorView(state.message);
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
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _ctrl,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingBody extends StatelessWidget {
  final Shipment shipment;
  const _TrackingBody({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MapSection(shipment: shipment),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrderHeaderCard(shipment: shipment),
                const SizedBox(height: 16),
                _RouteCard(shipment: shipment),
                const SizedBox(height: 16),
                _StatusTimeline(status: shipment.status),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapSection extends StatelessWidget {
  final Shipment shipment;
  const _MapSection({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: SizedBox(
        height: 240,
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
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Dropoff'),
        ),
      };

  @override
  void dispose() {
    try {
      _controller?.dispose();
    } catch (_) {
      // GoogleMapController may assert if user navigates away before buildView completes.
    }
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
      color: AppColors.surfaceVariant,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, color: AppColors.onSurface, size: 44),
                const SizedBox(height: 8),
                Text(
                  'Map Preview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '--dart-define=MAPS_API_KEY=<key>',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.6),
                        fontFamily: 'monospace',
                        fontSize: 11,
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
                geo: shipment.pickupGeo),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: _GeoTag(
                icon: Icons.location_on_rounded,
                color: AppColors.error,
                geo: shipment.dropoffGeo),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            '${geo.latitude.toStringAsFixed(3)}, ${geo.longitude.toStringAsFixed(3)}',
            style: const TextStyle(
                color: AppColors.onBackground, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _OrderHeaderCard extends StatelessWidget {
  final Shipment shipment;
  const _OrderHeaderCard({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppGradients.logistics,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shipment.orderNo,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  shipment.driverId != null ? 'Driver assigned' : 'Awaiting driver',
                  style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
                ),
                if (shipment.driverId != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => context.push('/logistics/chat/${shipment.id}'),
                    child: const Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            color: AppColors.primary, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Chat with Driver',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          _StatusChip(shipment.status),
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
        border: Border.all(color: AppColors.divider),
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
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Row(
              children: [
                Container(width: 2, height: 20, color: AppColors.divider),
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
                  style: const TextStyle(color: AppColors.onSurface, fontSize: 11)),
              Text(
                '${geo.latitude.toStringAsFixed(5)}, ${geo.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
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
    (ShipmentStatus.pending, Icons.schedule_rounded, 'Order Placed'),
    (ShipmentStatus.assigned, Icons.person_pin_rounded, 'Driver Assigned'),
    (ShipmentStatus.pickedUp, Icons.inventory_2_outlined, 'Picked Up'),
    (ShipmentStatus.shipping, Icons.local_shipping_outlined, 'In Transit'),
    (ShipmentStatus.delivered, Icons.check_circle_outline_rounded, 'Delivered'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx =
        _steps.indexWhere((s) => s.$1 == status).clamp(0, _steps.length - 1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Progress',
            style: TextStyle(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_steps.length, (i) {
            final (_, icon, label) = _steps[i];
            final isDone = currentIdx >= i;
            final isActive = currentIdx == i;
            return _TimelineStep(
              icon: icon,
              label: label,
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
  final IconData icon;
  final String label;
  final bool isDone;
  final bool isActive;
  final bool isLast;
  const _TimelineStep({
    required this.icon,
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isActive ? AppColors.primary : AppColors.success;
    final dotColor = isDone ? activeColor : AppColors.surfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: dotColor,
                border: Border.all(
                  color: isDone ? dotColor : AppColors.divider,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: isDone
                  ? Icon(
                      isActive ? icon : Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: isDone
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.divider,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: TextStyle(
              color: isActive
                  ? AppColors.primary
                  : isDone
                      ? AppColors.onBackground
                      : AppColors.onSurface,
              fontWeight:
                  isActive || isDone ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
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
        ShipmentStatus.assigned || ShipmentStatus.pickedUp => AppColors.info,
        ShipmentStatus.shipping => AppColors.primary,
        ShipmentStatus.delivered => AppColors.success,
        ShipmentStatus.cancelled => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message,
          style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
    );
  }
}
