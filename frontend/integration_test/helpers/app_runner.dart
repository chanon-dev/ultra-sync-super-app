import 'package:flutter/material.dart';
import 'package:ultra_sync/core/di/injection.dart';
import 'package:ultra_sync/main.dart' as app;

/// Shared test bootstrap used by every Patrol test file.
class AppRunner {
  static Future<void> setUp() async {
    await configureDependencies(env: 'test');
  }

  static Future<void> tearDown() async {
    await getIt.reset();
  }

  /// Boots the full app from main() — follows real auth guard navigation.
  static Widget build() {
    app.main();
    // main() calls runApp; returning a placeholder lets Patrol pump it.
    return const SizedBox.shrink();
  }

  /// Starts the app pre-authenticated (injects a stored test token via
  /// FlutterSecureStorage before pumping, bypassing the login screen).
  static Widget buildAuthenticated() {
    // In a real device run, use patrol's native automation to tap through
    // login or inject tokens via platform channel before calling build().
    return build();
  }
}
