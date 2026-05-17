import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/auth/domain/entities/user.dart';
import 'package:ultra_sync/features/auth/domain/repositories/auth_repository.dart';

@lazySingleton
class CheckAuthUseCase implements UseCase<TokenPair, NoParams> {
  final AuthRepository _repository;

  const CheckAuthUseCase(this._repository);

  @override
  Future<Either<Failure, TokenPair>> call(NoParams params) async {
    final refreshToken = await _repository.getStoredRefreshToken();
    if (refreshToken == null) {
      return const Left(UnauthorizedFailure(message: 'No active session'));
    }
    return _repository.refreshToken(refreshToken);
  }
}
