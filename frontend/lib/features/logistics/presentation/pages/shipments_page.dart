import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';
import 'package:ultra_sync/core/utils/date_formatter.dart';
import 'package:ultra_sync/core/widgets/app_snack_bar.dart';
import 'package:ultra_sync/features/logistics/domain/entities/shipment.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_bloc.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_event.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_state.dart';

class ShipmentsPage extends StatefulWidget {
  const ShipmentsPage({super.key});

  @override
  State<ShipmentsPage> createState() => _ShipmentsPageState();
}

class _ShipmentsPageState extends State<ShipmentsPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ShipmentsBloc>().add(const ShipmentsLoadRequested());
    _searchCtrl.addListener(
      () => context.read<ShipmentsBloc>().add(ShipmentsSearchChanged(_searchCtrl.text)),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<ShipmentsBloc, ShipmentsState>(
        listener: (context, state) {
          if (state is ShipmentCreated) {
            AppSnackBar.showSuccess(
              context,
              'Shipment ${state.shipment.orderNo} created!',
            );
            context.read<ShipmentsBloc>().add(const ShipmentsLoadRequested());
          }
        },
        builder: (context, state) {
          final activeFilter =
              state is ShipmentsLoaded ? state.activeFilter : null;

          return SafeArea(
            child: Column(
              children: [
                _TopBar(
                  searchCtrl: _searchCtrl,
                  onRefresh: () =>
                      context.read<ShipmentsBloc>().add(const ShipmentsLoadRequested()),
                ),
                _FilterRow(
                  selected: activeFilter,
                  onSelect: (f) =>
                      context.read<ShipmentsBloc>().add(ShipmentsFilterChanged(f)),
                ),
                Expanded(child: _Body(state: state)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _NewShipmentFab(),
    );
  }
}

class _TopBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final VoidCallback onRefresh;

  const _TopBar({required this.searchCtrl, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Shipments',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.onSurface),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final ShipmentStatus? selected;
  final ValueChanged<ShipmentStatus?> onSelect;

  const _FilterRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const filters = [
      (null, 'All'),
      (ShipmentStatus.pending, 'Pending'),
      (ShipmentStatus.shipping, 'In Transit'),
      (ShipmentStatus.delivered, 'Delivered'),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: filters.length,
        itemBuilder: (context, i) {
          final (status, label) = filters[i];
          final isSelected = selected == status;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: () => onSelect(status),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ShipmentsState state;

  const _Body({required this.state});

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ShipmentsLoading() => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      ShipmentsError(:final message) => _ErrorView(
          message: message,
          onRetry: () =>
              context.read<ShipmentsBloc>().add(const ShipmentsLoadRequested()),
        ),
      ShipmentsLoaded(:final filtered) => filtered.isEmpty
          ? const _EmptyView()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ShipmentCard(shipment: filtered[i]),
            ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ShipmentCard extends StatelessWidget {
  final Shipment shipment;
  const _ShipmentCard({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await context.push('/logistics/track/${shipment.id}');
            if (context.mounted) {
              context.read<ShipmentsBloc>().add(const ShipmentsLoadRequested());
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_shipping_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shipment.orderNo,
                            style: const TextStyle(
                              color: AppColors.onBackground,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            DateFormatter.formatDateTime(shipment.createdAt),
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: shipment.status),
                  ],
                ),
                const SizedBox(height: 16),
                _RouteVisual(shipment: shipment),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteVisual extends StatelessWidget {
  final Shipment shipment;
  const _RouteVisual({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 24, color: AppColors.divider),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${shipment.pickupGeo.latitude.toStringAsFixed(4)}, '
                '${shipment.pickupGeo.longitude.toStringAsFixed(4)}',
                style: const TextStyle(color: AppColors.onSurface, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Text(
                '${shipment.dropoffGeo.latitude.toStringAsFixed(4)}, '
                '${shipment.dropoffGeo.longitude.toStringAsFixed(4)}',
                style: const TextStyle(color: AppColors.onSurface, fontSize: 12),
              ),
            ],
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
        ShipmentStatus.assigned || ShipmentStatus.pickedUp => AppColors.info,
        ShipmentStatus.shipping => AppColors.primary,
        ShipmentStatus.delivered => AppColors.success,
        ShipmentStatus.cancelled => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _NewShipmentFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.primary,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/logistics/create'),
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'New Shipment',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
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
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_outlined,
                color: AppColors.onSurface, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'No shipments yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first shipment',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.onSurface),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 32),
            ),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(color: AppColors.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: 140,
              child: ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
