import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_bloc.dart';

class ShipmentsPage extends StatefulWidget {
  const ShipmentsPage({super.key});

  @override
  State<ShipmentsPage> createState() => _ShipmentsPageState();
}

class _ShipmentsPageState extends State<ShipmentsPage> {
  @override
  void initState() {
    super.initState();
    context.read<ShipmentsBloc>().add(const ShipmentsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                context.read<ShipmentsBloc>().add(const ShipmentsLoadRequested()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/logistics/create'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Shipment', style: TextStyle(color: Colors.white)),
      ),
      body: BlocConsumer<ShipmentsBloc, ShipmentsState>(
        listener: (context, state) {
          if (state is ShipmentCreated) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Shipment ${state.shipment.orderNo} created!'),
              backgroundColor: AppColors.secondary,
            ));
            context.read<ShipmentsBloc>().add(const ShipmentsLoadRequested());
          }
        },
        builder: (context, state) {
          if (state is ShipmentsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is ShipmentsError) {
            return _ErrorView(message: state.message, onRetry: () {
              context.read<ShipmentsBloc>().add(const ShipmentsLoadRequested());
            });
          }
          if (state is ShipmentsLoaded) {
            if (state.shipments.isEmpty) {
              return const _EmptyView();
            }
            return _ShipmentList(shipments: state.shipments);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ShipmentList extends StatelessWidget {
  final List<Shipment> shipments;
  const _ShipmentList({required this.shipments});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: shipments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _ShipmentCard(shipment: shipments[i]),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  final Shipment shipment;
  const _ShipmentCard({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/logistics/track/${shipment.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    shipment.orderNo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.onBackground,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  _StatusBadge(status: shipment.status),
                ],
              ),
              const SizedBox(height: 12),
              _GeoRow(
                icon: Icons.my_location_rounded,
                label: 'Pickup',
                geo: shipment.pickupGeo,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              _GeoRow(
                icon: Icons.location_on_rounded,
                label: 'Dropoff',
                geo: shipment.dropoffGeo,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                _formatDate(shipment.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _GeoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final GeoPoint geo;
  final Color color;

  const _GeoRow({
    required this.icon,
    required this.label,
    required this.geo,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ${geo.latitude.toStringAsFixed(4)}, ${geo.longitude.toStringAsFixed(4)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurface,
              ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ShipmentStatus status;
  const _StatusBadge({required this.status});

  Color get _color => switch (status) {
        ShipmentStatus.pending => AppColors.warning,
        ShipmentStatus.assigned => AppColors.primary,
        ShipmentStatus.pickedUp => AppColors.primary,
        ShipmentStatus.shipping => AppColors.secondary,
        ShipmentStatus.delivered => AppColors.secondary,
        ShipmentStatus.cancelled => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_shipping_outlined,
              color: AppColors.onSurface, size: 64),
          const SizedBox(height: 16),
          Text(
            'No shipments yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first shipment',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: AppColors.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
