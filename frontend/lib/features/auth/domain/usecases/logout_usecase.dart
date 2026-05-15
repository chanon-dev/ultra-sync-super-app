import 'package:fpdart/fpdart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/auth/domain/repositories/auth_repository.dart';

@lazySingleton
class LogoutUseCase implements UseCase<Unit, NoParams> {
  final AuthRepository _repository;
  final FlutterSecureStorage _storage;

  const LogoutUseCase(this._repository, this._storage);

  @override
  Future<Either<Failure, Unit>> call(NoParams params) async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) {
      return const Right(unit);
    }
    return _repository.logout(refreshToken);
  }
}
