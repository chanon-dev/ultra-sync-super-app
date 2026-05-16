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
    'shipments list loads and shows empty or populated state',
    ($) async {
      await $.pumpWidgetAndSettle(AppRunner.buildAuthenticated());
      await $.waitUntilVisible(find.text('Ultra-Sync'));

      await $('Logistics').tap();
      await $.waitUntilVisible(find.text('Shipments'));

      // Either a shipment card or the empty state is visible.
      final hasShipments = find.textContaining('ORD-').evaluate().isNotEmpty;
      final hasEmpty = find.text('No shipments yet').evaluate().isNotEmpty;
      expect(hasShipments || hasEmpty, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  patrolTest(
    'creates a new shipment with valid coordinates',
    ($) async {
      await $.pumpWidgetAndSettle(AppRunner.buildAuthenticated());
      await $('Logistics').tap();
      await $.waitUntilVisible(find.text('Shipments'));

      await $(Icons.add_rounded).tap();
      await $.waitUntilVisible(find.text('New Shipment'));

      // Fill pickup.
      await $(#pickupLatField).enterText('13.7563');
      await $(#pickupLngField).enterText('100.5018');
      // Fill dropoff.
      await $(#dropoffLatField).enterText('13.8621');
      await $(#dropoffLngField).enterText('100.6086');

      await $('Create Shipment').tap();

      // Should navigate back to list and show the new order.
      await $.waitUntilVisible(find.text('Shipments'));
      await $.waitUntilVisible(find.textContaining('ORD-'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  patrolTest(
    'tracking page opens for a shipment',
    ($) async {
      await $.pumpWidgetAndSettle(AppRunner.buildAuthenticated());
      await $('Logistics').tap();
      await $.waitUntilVisible(find.textContaining('ORD-'));

      // Tap the first shipment card.
      await $(find.textContaining('ORD-')).first.tap();
      await $.waitUntilVisible(find.text('Live Tracking'));
      expect(find.text('LIVE'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
