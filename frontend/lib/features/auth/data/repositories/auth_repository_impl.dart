import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/network/api_client.dart';
import 'package:ultra_sync/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ultra_sync/features/auth/domain/entities/user.dart';
import 'package:ultra_sync/features/auth/domain/repositories/auth_repository.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final ApiClient _apiClient;

  AuthRepositoryImpl(this._remote, this._apiClient);

  @override
  Future<Either<Failure, User>> register({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final user = await _remote.register(email: email, password: password, role: role);
      return Right(user);
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
      final tokens = await _remote.login(email: email, password: password);
      await _apiClient.saveTokens(
        access: tokens.accessToken,
        refresh: tokens.refreshToken,
      );
      return Right(tokens);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TokenPair>> refreshToken(String refreshToken) async {
    try {
      final tokens = await _remote.refreshToken(refreshToken);
      await _apiClient.saveTokens(
        access: tokens.accessToken,
        refresh: tokens.refreshToken,
      );
      return Right(tokens);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(const UnauthorizedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> logout(String refreshToken) async {
    try {
      await _remote.logout(refreshToken);
      await _apiClient.clearTokens();
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      await _apiClient.clearTokens();
      return const Right(unit); // Always clear local tokens regardless
    }
  }

  @override
  Future<Either<Failure, User?>> getCachedUser() async {
    // Phase 2: implement local cache with shared_preferences
    return const Right(null);
  }
}
