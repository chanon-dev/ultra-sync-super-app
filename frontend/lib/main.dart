import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ultra_sync/core/di/injection.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';
import 'package:ultra_sync/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ultra_sync/features/auth/presentation/pages/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(const UltraSyncApp());
}

class UltraSyncApp extends StatelessWidget {
  const UltraSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const AuthCheckRequested()),
        ),
      ],
      child: MaterialApp(
        title: 'Ultra-Sync',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: const LoginPage(),
        // TODO Phase 2: replace with go_router
      ),
    );
  }
}
