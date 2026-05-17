import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/ports/token_storage.dart';
import 'package:ultra_sync/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ultra_sync/features/auth/domain/entities/user.dart';
import 'package:ultra_sync/features/auth/domain/repositories/auth_repository.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  AuthRepositoryImpl(this._remote, this._tokenStorage);

  @override
  Future<Either<Failure, User>> register({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final model = await _remote.register(email: email, password: password, role: role);
      return Right(model.toDomain());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TokenPair>> login({
    required String email,
    required String password,
  }) async {
    try {
      final model = await _remote.login(email: email, password: password);
      await _tokenStorage.save(
        access: model.accessToken,
        refresh: model.refreshToken,
      );
      return Right(model.toDomain());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TokenPair>> refreshToken(String refreshToken) async {
    try {
      final model = await _remote.refreshToken(refreshToken);
      await _tokenStorage.save(
        access: model.accessToken,
        refresh: model.refreshToken,
      );
      return Right(model.toDomain());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return const Left(UnauthorizedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> logout(String refreshToken) async {
    try {
      await _remote.logout(refreshToken);
      await _tokenStorage.clear();
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      // Always clear local tokens even if server call fails.
      await _tokenStorage.clear();
      return const Right(unit);
    }
  }

  @override
  Future<Either<Failure, User?>> getCachedUser() async {
    return const Right(null);
  }

  @override
  Future<String?> getStoredRefreshToken() => _tokenStorage.getRefreshToken();
}
