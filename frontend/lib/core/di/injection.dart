import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/network/api_client.dart';
import 'package:ultra_sync/core/ports/token_storage.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
void configureDependencies({String env = 'dev'}) {
  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(
      webOptions: WebOptions(
        dbName: 'UltraSync',
        publicKey: 'UltraSyncPublicKey',
      ),
    ),
  );

  // ApiClient depends on TokenStorage, which is registered lazily by getIt.init().
  // Both are lazy singletons so the factory runs only on first access — by then
  // all injectable registrations are complete.
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(
      baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080',
      tokenStorage: getIt<TokenStorage>(),
    ),
  );

  getIt.init(environment: env);
}
