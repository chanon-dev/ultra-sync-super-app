import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/network/api_client.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
void configureDependencies({String env = 'dev'}) {
  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(
      baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080',
      storage: getIt<FlutterSecureStorage>(),
    ),
  );
  getIt.init(environment: env);
}
