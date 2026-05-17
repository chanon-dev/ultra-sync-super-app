// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:ultra_sync/core/network/api_client.dart' as _i513;
import 'package:ultra_sync/core/ports/token_storage.dart' as _i700;
import 'package:ultra_sync/core/services/biometric_service.dart' as _i874;
import 'package:ultra_sync/core/services/location_service.dart' as _i330;
import 'package:ultra_sync/core/services/token_storage_impl.dart' as _i34;
import 'package:ultra_sync/features/auth/data/datasources/auth_remote_data_source.dart'
    as _i853;
import 'package:ultra_sync/features/auth/data/repositories/auth_repository_impl.dart'
    as _i814;
import 'package:ultra_sync/features/auth/domain/repositories/auth_repository.dart'
    as _i951;
import 'package:ultra_sync/features/auth/domain/usecases/check_auth_usecase.dart'
    as _i611;
import 'package:ultra_sync/features/auth/domain/usecases/login_usecase.dart'
    as _i485;
import 'package:ultra_sync/features/auth/domain/usecases/logout_usecase.dart'
    as _i994;
import 'package:ultra_sync/features/auth/domain/usecases/register_usecase.dart'
    as _i876;
import 'package:ultra_sync/features/auth/presentation/bloc/auth_bloc.dart'
    as _i135;
import 'package:ultra_sync/features/logistics/data/datasources/shipment_remote_data_source.dart'
    as _i180;
import 'package:ultra_sync/features/logistics/data/repositories/shipment_repository_impl.dart'
    as _i243;
import 'package:ultra_sync/features/logistics/domain/repositories/shipment_repository.dart'
    as _i173;
import 'package:ultra_sync/features/logistics/domain/usecases/create_shipment_usecase.dart'
    as _i995;
import 'package:ultra_sync/features/logistics/domain/usecases/get_shipment_usecase.dart'
    as _i374;
import 'package:ultra_sync/features/logistics/domain/usecases/list_shipments_usecase.dart'
    as _i254;
import 'package:ultra_sync/features/logistics/presentation/bloc/shipments_bloc.dart'
    as _i160;
import 'package:ultra_sync/features/wallet/data/datasources/wallet_remote_data_source.dart'
    as _i640;
import 'package:ultra_sync/features/wallet/data/repositories/wallet_repository_impl.dart'
    as _i777;
import 'package:ultra_sync/features/wallet/domain/repositories/wallet_repository.dart'
    as _i945;
import 'package:ultra_sync/features/wallet/domain/usecases/get_balance_usecase.dart'
    as _i906;
import 'package:ultra_sync/features/wallet/domain/usecases/list_transactions_usecase.dart'
    as _i493;
import 'package:ultra_sync/features/wallet/domain/usecases/top_up_usecase.dart'
    as _i788;
import 'package:ultra_sync/features/wallet/presentation/bloc/wallet_bloc.dart'
    as _i235;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    gh.lazySingleton<_i874.BiometricService>(() => _i874.BiometricService());
    gh.lazySingleton<_i180.ShipmentRemoteDataSource>(
        () => _i180.ShipmentRemoteDataSourceImpl(gh<_i513.ApiClient>()));
    gh.lazySingleton<_i640.WalletRemoteDataSource>(
        () => _i640.WalletRemoteDataSourceImpl(gh<_i513.ApiClient>()));
    gh.lazySingleton<_i700.TokenStorage>(
        () => _i34.TokenStorageImpl(gh<_i558.FlutterSecureStorage>()));
    gh.lazySingleton<_i853.AuthRemoteDataSource>(
        () => _i853.AuthRemoteDataSourceImpl(gh<_i513.ApiClient>()));
    gh.lazySingleton<_i330.LocationService>(
        () => _i330.LocationService(gh<_i513.ApiClient>()));
    gh.lazySingleton<_i945.WalletRepository>(
        () => _i777.WalletRepositoryImpl(gh<_i640.WalletRemoteDataSource>()));
    gh.lazySingleton<_i951.AuthRepository>(() => _i814.AuthRepositoryImpl(
          gh<_i853.AuthRemoteDataSource>(),
          gh<_i700.TokenStorage>(),
        ));
    gh.lazySingleton<_i485.LoginUseCase>(
        () => _i485.LoginUseCase(gh<_i951.AuthRepository>()));
    gh.lazySingleton<_i876.RegisterUseCase>(
        () => _i876.RegisterUseCase(gh<_i951.AuthRepository>()));
    gh.lazySingleton<_i173.ShipmentRepository>(() =>
        _i243.ShipmentRepositoryImpl(gh<_i180.ShipmentRemoteDataSource>()));
    gh.lazySingleton<_i906.GetBalanceUseCase>(
        () => _i906.GetBalanceUseCase(gh<_i945.WalletRepository>()));
    gh.lazySingleton<_i493.ListTransactionsUseCase>(
        () => _i493.ListTransactionsUseCase(gh<_i945.WalletRepository>()));
    gh.lazySingleton<_i788.TopUpUseCase>(
        () => _i788.TopUpUseCase(gh<_i945.WalletRepository>()));
    gh.lazySingleton<_i611.CheckAuthUseCase>(() => _i611.CheckAuthUseCase(
          gh<_i951.AuthRepository>(),
          gh<_i700.TokenStorage>(),
        ));
    gh.lazySingleton<_i994.LogoutUseCase>(() => _i994.LogoutUseCase(
          gh<_i951.AuthRepository>(),
          gh<_i700.TokenStorage>(),
        ));
    gh.factory<_i135.AuthBloc>(() => _i135.AuthBloc(
          login: gh<_i485.LoginUseCase>(),
          register: gh<_i876.RegisterUseCase>(),
          logout: gh<_i994.LogoutUseCase>(),
          checkAuth: gh<_i611.CheckAuthUseCase>(),
          biometrics: gh<_i874.BiometricService>(),
        ));
    gh.lazySingleton<_i995.CreateShipmentUseCase>(
        () => _i995.CreateShipmentUseCase(gh<_i173.ShipmentRepository>()));
    gh.lazySingleton<_i374.GetShipmentUseCase>(
        () => _i374.GetShipmentUseCase(gh<_i173.ShipmentRepository>()));
    gh.lazySingleton<_i254.ListShipmentsUseCase>(
        () => _i254.ListShipmentsUseCase(gh<_i173.ShipmentRepository>()));
    gh.factory<_i160.ShipmentsBloc>(() => _i160.ShipmentsBloc(
          list: gh<_i254.ListShipmentsUseCase>(),
          create: gh<_i995.CreateShipmentUseCase>(),
          get: gh<_i374.GetShipmentUseCase>(),
        ));
    gh.factory<_i235.WalletBloc>(() => _i235.WalletBloc(
          getBalance: gh<_i906.GetBalanceUseCase>(),
          topUp: gh<_i788.TopUpUseCase>(),
          listTransactions: gh<_i493.ListTransactionsUseCase>(),
        ));
    return this;
  }
}
