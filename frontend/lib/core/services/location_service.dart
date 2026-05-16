import 'dart:async';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/network/api_client.dart';

/// Streams the device GPS position and publishes each fix to the logistics
/// service as a driver location update (POST /api/v1/drivers/location).
///
/// Usage (driver side):
///   locationService.startTracking(shipmentId: id);
///   // … later …
///   locationService.stopTracking();
@lazySingleton
class LocationService {
  final ApiClient _client;

  StreamSubscription<Position>? _subscription;

  LocationService(this._client);

  bool get isTracking => _subscription != null;

  /// Requests permission then begins streaming location to the backend.
  /// Resolves [accuracy] defaults to the best available fix.
  Future<void> startTracking({
    required String shipmentId,
    LocationAccuracy accuracy = LocationAccuracy.high,
    int intervalMs = 5000,
  }) async {
    await _ensurePermission();

    final settings = AndroidSettings(
      accuracy: accuracy,
      intervalDuration: Duration(milliseconds: intervalMs),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Ultra-Sync Driver',
        notificationText: 'Tracking your delivery location',
        enableWakeLock: true,
      ),
    );

    _subscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (pos) => _publish(shipmentId, pos),
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _publish(String shipmentId, Position pos) async {
    try {
      await _client.dio.post(
        '/api/v1/drivers/location',
        data: {
          'shipment_id': shipmentId,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'speed_kmh': (pos.speed * 3.6).clamp(0, double.infinity),
        },
      );
    } on DioException {
      // Non-fatal: missed fix will be recovered on next interval.
    }
  }

  static Future<void> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. '
          'Enable it in device settings.');
    }
  }
}
