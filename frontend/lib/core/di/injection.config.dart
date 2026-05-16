// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/network/api_client.dart';
import 'package:ultra_sync/core/services/biometric_service.dart';
import 'package:ultra_sync/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ultra_sync/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ultra_sync/features/auth/domain/repositories/auth_repository.dart';
import 'package:ultra_sync/features/auth/domain/usecases/check_auth_usecase.dart';
import 'package:ultra_sync/features/auth/domain/usecases/login_usecase.dart';
import 'package:ultra_sync/features/auth/domain/usecases/logout_usecase.dart';
import 'package:ultra_sync/features/auth/domain/usecases/register_usecase.dart';
import 'package:ultra_sync/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ultra_sync/features/logistics/data/datasources/shipment_remote_data_source.dart';
import 'package:ultra_sync/features/logistics/data/repositories/shipment_repository_impl.dart';
import 'package:ultra_sync/features/logistics/domain/repositories/shipment_repository.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/create_shipment_usecase.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/get_shipment_usecase.dart';
import 'package:ultra_sync/features/logistics/domain/usecases/list_shipments_usecase.dart';
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_bloc.dart';
import 'package:ultra_sync/features/wallet/data/datasources/wallet_remote_data_source.dart';
import 'package:ultra_sync/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:ultra_sync/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/get_balance_usecase.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/list_transactions_usecase.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/top_up_usecase.dart';
import 'package:ultra_sync/features/wallet/presentation/bloc/wallet_bloc.dart';

extension GetItInjectableX on GetIt {
  // ignore: unused_element
  GetIt init({
    String? environment,
    EnvironmentFilter? environmentFilter,
  }) {
    final gh = GetItHelper(this, environment, environmentFilter);

    // ── Auth ──────────────────────────────────────────────────────────────
    gh.lazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(gh<ApiClient>()),
    );
    gh.lazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        gh<AuthRemoteDataSource>(),
        gh<ApiClient>(),
      ),
    );
    gh.lazySingleton<LoginUseCase>(
      () => LoginUseCase(gh<AuthRepository>()),
    );
    gh.lazySingleton<RegisterUseCase>(
      () => RegisterUseCase(gh<AuthRepository>()),
    );
    gh.lazySingleton<LogoutUseCase>(
      () => LogoutUseCase(
        gh<AuthRepository>(),
        gh<FlutterSecureStorage>(),
      ),
    );
    gh.lazySingleton<CheckAuthUseCase>(
      () => CheckAuthUseCase(
        gh<AuthRepository>(),
        gh<FlutterSecureStorage>(),
      ),
    );
    gh.lazySingleton<BiometricService>(
      () => BiometricService(),
    );
    gh.factory<AuthBloc>(
      () => AuthBloc(
        login: gh<LoginUseCase>(),
        register: gh<RegisterUseCase>(),
        logout: gh<LogoutUseCase>(),
        checkAuth: gh<CheckAuthUseCase>(),
        biometrics: gh<BiometricService>(),
      ),
    );

    // ── Logistics ─────────────────────────────────────────────────────────
    gh.lazySingleton<ShipmentRemoteDataSource>(
      () => ShipmentRemoteDataSourceImpl(gh<ApiClient>()),
    );
    gh.lazySingleton<ShipmentRepository>(
      () => ShipmentRepositoryImpl(gh<ShipmentRemoteDataSource>()),
    );
    gh.lazySingleton<CreateShipmentUseCase>(
      () => CreateShipmentUseCase(gh<ShipmentRepository>()),
    );
    gh.lazySingleton<ListShipmentsUseCase>(
      () => ListShipmentsUseCase(gh<ShipmentRepository>()),
    );
    gh.lazySingleton<GetShipmentUseCase>(
      () => GetShipmentUseCase(gh<ShipmentRepository>()),
    );
    gh.factory<ShipmentsBloc>(
      () => ShipmentsBloc(
        list: gh<ListShipmentsUseCase>(),
        create: gh<CreateShipmentUseCase>(),
        get: gh<GetShipmentUseCase>(),
      ),
    );

    // ── Wallet ────────────────────────────────────────────────────────────
    gh.lazySingleton<WalletRemoteDataSource>(
      () => WalletRemoteDataSourceImpl(gh<ApiClient>()),
    );
    gh.lazySingleton<WalletRepository>(
      () => WalletRepositoryImpl(gh<WalletRemoteDataSource>()),
    );
    gh.lazySingleton<GetBalanceUseCase>(
      () => GetBalanceUseCase(gh<WalletRepository>()),
    );
    gh.lazySingleton<TopUpUseCase>(
      () => TopUpUseCase(gh<WalletRepository>()),
    );
    gh.lazySingleton<ListTransactionsUseCase>(
      () => ListTransactionsUseCase(gh<WalletRepository>()),
    );
    gh.factory<WalletBloc>(
      () => WalletBloc(
        getBalance: gh<GetBalanceUseCase>(),
        topUp: gh<TopUpUseCase>(),
        listTransactions: gh<ListTransactionsUseCase>(),
      ),
    );

    return this;
  }
}
