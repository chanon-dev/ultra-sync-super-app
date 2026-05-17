import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ultra_sync/core/di/injection.dart';
import 'package:ultra_sync/core/router/main_shell.dart';
import 'package:ultra_sync/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ultra_sync/features/auth/presentation/bloc/auth_state.dart';
import 'package:ultra_sync/features/auth/presentation/pages/login_page.dart';
import 'package:ultra_sync/features/auth/presentation/pages/register_page.dart';
import 'package:ultra_sync/features/home/presentation/pages/home_page.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_bloc.dart';
import 'package:ultra_sync/features/logistics/presentation/pages/create_shipment_page.dart';
import 'package:ultra_sync/features/logistics/presentation/pages/shipments_page.dart';
import 'package:ultra_sync/features/logistics/presentation/pages/tracking_page.dart';
import 'package:ultra_sync/features/profile/presentation/pages/profile_page.dart';
import 'package:ultra_sync/features/splash/presentation/pages/splash_page.dart';
import 'package:ultra_sync/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:ultra_sync/features/wallet/presentation/pages/qr_receive_page.dart';
import 'package:ultra_sync/features/wallet/presentation/pages/qr_scan_page.dart';
import 'package:ultra_sync/features/wallet/presentation/pages/wallet_page.dart';

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthChangeNotifier(authBloc),
    redirect: (_, state) => _redirect(authBloc.state, state.matchedLocation),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterPage(),
      ),

      // Main shell — provides both BLoCs to all tabs + sub-routes
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => getIt<ShipmentsBloc>()),
            BlocProvider(create: (_) => getIt<WalletBloc>()),
          ],
          child: MainShell(navigationShell: navigationShell),
        ),
        branches: [
          // Tab 0 — Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const HomePage(),
              ),
            ],
          ),

          // Tab 1 — Wallet
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                builder: (_, __) => const WalletPage(),
                routes: [
                  GoRoute(
                    path: 'qr',
                    builder: (_, __) => const QrReceivePage(),
                  ),
                  GoRoute(
                    path: 'scan',
                    builder: (_, __) => const QrScanPage(),
                  ),
                ],
              ),
            ],
          ),

          // Tab 2 — Logistics / Activity
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/logistics',
                builder: (_, __) => const ShipmentsPage(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (_, __) => const CreateShipmentPage(),
                  ),
                  GoRoute(
                    path: 'track/:id',
                    builder: (_, state) =>
                        TrackingPage(shipmentId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),

          // Tab 3 — Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

String? _redirect(AuthState authState, String location) {
  final onAuthFlow = location == '/login' || location == '/register';

  if (authState is AuthInitial || authState is AuthLoading) {
    return location == '/splash' ? null : '/splash';
  }
  if (authState is AuthAuthenticated) {
    return onAuthFlow || location == '/splash' ? '/home' : null;
  }
  if (authState is AuthRegistered) {
    return onAuthFlow ? null : '/login';
  }
  // AuthUnauthenticated / AuthFailureState
  return onAuthFlow ? null : '/login';
}

class _AuthChangeNotifier extends ChangeNotifier {
  final AuthBloc _bloc;
  late final StreamSubscription<AuthState> _subscription;

  _AuthChangeNotifier(this._bloc) {
    _subscription = _bloc.stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
