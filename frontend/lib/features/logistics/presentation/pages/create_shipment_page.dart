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
      appBar: AppBar(title: const Text('New Shipment')),
      body: BlocListener<ShipmentsBloc, ShipmentsState>(
        listener: (context, state) {
          if (state is ShipmentCreated) {
            context.pop();
          }
          if (state is ShipmentsError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ));
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Pickup Location'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _CoordField(controller: _pickupLatCtrl, label: 'Latitude')),
                  const SizedBox(width: 12),
                  Expanded(child: _CoordField(controller: _pickupLngCtrl, label: 'Longitude')),
                ]),
                const SizedBox(height: 24),
                _SectionHeader('Dropoff Location'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _CoordField(controller: _dropoffLatCtrl, label: 'Latitude')),
                  const SizedBox(width: 12),
                  Expanded(child: _CoordField(controller: _dropoffLngCtrl, label: 'Longitude')),
                ]),
                const SizedBox(height: 32),
                _PreviewCard(
                  pickupLat: double.tryParse(_pickupLatCtrl.text) ?? 0,
                  pickupLng: double.tryParse(_pickupLngCtrl.text) ?? 0,
                  dropoffLat: double.tryParse(_dropoffLatCtrl.text) ?? 0,
                  dropoffLng: double.tryParse(_dropoffLngCtrl.text) ?? 0,
                ),
                const SizedBox(height: 32),
                BlocBuilder<ShipmentsBloc, ShipmentsState>(
                  builder: (context, state) => ElevatedButton(
                    onPressed: state is ShipmentsLoading ? null : _submit,
                    child: state is ShipmentsLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create Shipment'),
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

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: const TextStyle(color: AppColors.onBackground),
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (double.tryParse(v) == null) return 'Invalid number';
        return null;
      },
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final double pickupLat, pickupLng, dropoffLat, dropoffLng;
  const _PreviewCard({
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route Preview',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: 12),
          _RouteRow(
            icon: Icons.my_location_rounded,
            color: AppColors.primary,
            label: 'From',
            lat: pickupLat,
            lng: pickupLng,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              height: 20,
              child: VerticalDivider(color: AppColors.onSurface, width: 1),
            ),
          ),
          _RouteRow(
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

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double lat, lng;
  const _RouteRow({
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
            Text(label,
                style: const TextStyle(
                    color: AppColors.onSurface, fontSize: 11)),
            Text(
              '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
              style: const TextStyle(
                  color: AppColors.onBackground, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}
