import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ultra_sync/core/di/injection.dart';
import 'package:ultra_sync/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ultra_sync/features/auth/presentation/pages/home_page.dart';
import 'package:ultra_sync/features/auth/presentation/pages/login_page.dart';
import 'package:ultra_sync/features/auth/presentation/pages/register_page.dart';
import 'package:ultra_sync/features/auth/presentation/pages/splash_page.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_bloc.dart';
import 'package:ultra_sync/features/logistics/presentation/pages/create_shipment_page.dart';
import 'package:ultra_sync/features/logistics/presentation/pages/shipments_page.dart';
import 'package:ultra_sync/features/logistics/presentation/pages/tracking_page.dart';
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
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomePage(),
      ),
      ShellRoute(
        builder: (context, state, child) => BlocProvider(
          create: (_) => getIt<ShipmentsBloc>(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/logistics',
            builder: (_, __) => const ShipmentsPage(),
          ),
          GoRoute(
            path: '/logistics/create',
            builder: (_, __) => const CreateShipmentPage(),
          ),
          GoRoute(
            path: '/logistics/track/:id',
            builder: (_, state) =>
                TrackingPage(shipmentId: state.pathParameters['id']!),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => BlocProvider(
          create: (_) => getIt<WalletBloc>(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/wallet',
            builder: (_, __) => const WalletPage(),
          ),
          GoRoute(
            path: '/wallet/qr',
            builder: (_, __) => const QrReceivePage(),
          ),
          GoRoute(
            path: '/wallet/scan',
            builder: (_, __) => const QrScanPage(),
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
