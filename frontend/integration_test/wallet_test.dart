import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/app_runner.dart';

void main() {
  patrolSetUp(() async {
    await AppRunner.setUp();
  });

  patrolTearDown(() async {
    await AppRunner.tearDown();
  });

  patrolTest(
    'wallet page loads balance card',
    ($) async {
      await $.pumpWidgetAndSettle(AppRunner.buildAuthenticated());
      await $.waitUntilVisible(find.text('Ultra-Sync'));

      await $('Wallet').tap();
      await $.waitUntilVisible(find.text('Available Balance'));

      expect(find.text('Top Up'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  patrolTest(
    'top-up flow: enters amount and confirms',
    ($) async {
      await $.pumpWidgetAndSettle(AppRunner.buildAuthenticated());
      await $('Wallet').tap();
      await $.waitUntilVisible(find.text('Top Up'));

      await $('Top Up').tap();
      await $.waitUntilVisible(find.text('Top Up Wallet'));

      // Tap a preset chip.
      await $('100').tap();

      // Confirm.
      await $('Confirm Top Up').tap();

      // SnackBar confirms success.
      await $.waitUntilVisible(find.textContaining('Topped up'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  patrolTest(
    'QR receive page shows QR code',
    ($) async {
      await $.pumpWidgetAndSettle(AppRunner.buildAuthenticated());
      await $('Wallet').tap();
      await $.waitUntilVisible(find.byIcon(Icons.qr_code_rounded));

      await $(Icons.qr_code_rounded).tap();
      await $.waitUntilVisible(find.text('Scan to Pay Me'));
      expect(find.text('Receive Payment'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
