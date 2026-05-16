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
    'registers a new account and lands on home',
    ($) async {
      await $.pumpWidgetAndSettle(AppRunner.build());

      // Should land on splash then redirect to login.
      await $.waitUntilVisible(find.text('Sign In'));

      await $('Register').tap();
      await $.waitUntilVisible(find.text('Create Account'));

      await $(#emailField).enterText('e2e_${DateTime.now().millisecondsSinceEpoch}@test.com');
      await $(#passwordField).enterText('TestPass123!');
      await $('Create Account').tap();

      // After registration user is redirected to login.
      await $.waitUntilVisible(find.text('Sign In'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  patrolTest(
    'logs in with valid credentials and lands on home',
    ($) async {
      await $.pumpWidgetAndSettle(AppRunner.build());
      await $.waitUntilVisible(find.text('Sign In'));

      await $(#emailField).enterText('demo@ultra-sync.io');
      await $(#passwordField).enterText('Demo1234!');
      await $('Sign In').tap();

      await $.waitUntilVisible(find.text('Ultra-Sync'));
      expect(find.text('Logistics'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  patrolTest(
    'logs out and returns to login screen',
    ($) async {
      await $.pumpWidgetAndSettle(AppRunner.build());
      await $.waitUntilVisible(find.text('Sign In'));

      await $(#emailField).enterText('demo@ultra-sync.io');
      await $(#passwordField).enterText('Demo1234!');
      await $('Sign In').tap();
      await $.waitUntilVisible(find.text('Ultra-Sync'));

      await $(Icons.logout_rounded).tap();
      await $.waitUntilVisible(find.text('Sign In'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
