import 'package:fpdart/fpdart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/auth/domain/entities/user.dart';
import 'package:ultra_sync/features/auth/domain/repositories/auth_repository.dart';

@lazySingleton
class CheckAuthUseCase implements UseCase<TokenPair, NoParams> {
  final AuthRepository _repository;
  final FlutterSecureStorage _storage;

  const CheckAuthUseCase(this._repository, this._storage);

  @override
  Future<Either<Failure, TokenPair>> call(NoParams params) async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) {
      return const Left(UnauthorizedFailure(message: 'No active session'));
    }
    return _repository.refreshToken(refreshToken);
  }
}
