import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_bloc.dart';

class CreateShipmentPage extends StatefulWidget {
  const CreateShipmentPage({super.key});

  @override
  State<CreateShipmentPage> createState() => _CreateShipmentPageState();
}

class _CreateShipmentPageState extends State<CreateShipmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _pickupLatCtrl = TextEditingController(text: '13.7563');
  final _pickupLngCtrl = TextEditingController(text: '100.5018');
  final _dropoffLatCtrl = TextEditingController(text: '13.7308');
  final _dropoffLngCtrl = TextEditingController(text: '100.5210');

  @override
  void dispose() {
    _pickupLatCtrl.dispose();
    _pickupLngCtrl.dispose();
    _dropoffLatCtrl.dispose();
    _dropoffLngCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ShipmentsBloc>().add(ShipmentCreateRequested(
          pickupLat: double.parse(_pickupLatCtrl.text),
          pickupLng: double.parse(_pickupLngCtrl.text),
          dropoffLat: double.parse(_dropoffLatCtrl.text),
          dropoffLng: double.parse(_dropoffLngCtrl.text),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Shipment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<ShipmentsBloc, ShipmentsState>(
        listener: (context, state) {
          if (state is ShipmentCreated) context.pop();
          if (state is ShipmentsError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const _ProgressIndicator(step: 1, total: 2),
              const SizedBox(height: 24),
              _LocationSection(
                step: 1,
                title: 'Pickup Location',
                subtitle: 'Where should we pick up the package?',
                icon: Icons.my_location_rounded,
                color: AppColors.primary,
                latCtrl: _pickupLatCtrl,
                lngCtrl: _pickupLngCtrl,
              ),
              const SizedBox(height: 8),
              const _RouteConnector(),
              const SizedBox(height: 8),
              _LocationSection(
                step: 2,
                title: 'Dropoff Location',
                subtitle: 'Where should we deliver the package?',
                icon: Icons.location_on_rounded,
                color: AppColors.error,
                latCtrl: _dropoffLatCtrl,
                lngCtrl: _dropoffLngCtrl,
              ),
              const SizedBox(height: 24),
              _RoutePreviewCard(
                pickupLat: double.tryParse(_pickupLatCtrl.text) ?? 0,
                pickupLng: double.tryParse(_pickupLngCtrl.text) ?? 0,
                dropoffLat: double.tryParse(_dropoffLatCtrl.text) ?? 0,
                dropoffLng: double.tryParse(_dropoffLngCtrl.text) ?? 0,
              ),
              const SizedBox(height: 28),
              BlocBuilder<ShipmentsBloc, ShipmentsState>(
                builder: (context, state) => ElevatedButton(
                  onPressed: state is ShipmentsLoading ? null : _submit,
                  child: state is ShipmentsLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Create Shipment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressIndicator({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              gradient: active ? AppGradients.primary : null,
              color: active ? null : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _LocationSection extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final TextEditingController latCtrl;
  final TextEditingController lngCtrl;

  const _LocationSection({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.latCtrl,
    required this.lngCtrl,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.onBackground,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CoordField(controller: latCtrl, label: 'Latitude'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CoordField(controller: lngCtrl, label: 'Longitude'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _CoordField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: const TextStyle(color: AppColors.onBackground, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (double.tryParse(v) == null) return 'Invalid';
        return null;
      },
    );
  }
}

class _RouteConnector extends StatelessWidget {
  const _RouteConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 33),
      child: Column(
        children: List.generate(
          4,
          (i) => Container(
            width: 2,
            height: 6,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutePreviewCard extends StatelessWidget {
  final double pickupLat, pickupLng, dropoffLat, dropoffLng;
  const _RoutePreviewCard({
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_outlined, color: AppColors.onSurface, size: 16),
              const SizedBox(width: 8),
              Text(
                'Route Preview',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PreviewRow(
            icon: Icons.my_location_rounded,
            color: AppColors.primary,
            label: 'From',
            lat: pickupLat,
            lng: pickupLng,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Container(
              width: 2,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          _PreviewRow(
            icon: Icons.location_on_rounded,
            color: AppColors.error,
            label: 'To',
            lat: dropoffLat,
            lng: dropoffLng,
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double lat, lng;
  const _PreviewRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 11),
            ),
            Text(
              '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
              style: const TextStyle(
                color: AppColors.onBackground,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
