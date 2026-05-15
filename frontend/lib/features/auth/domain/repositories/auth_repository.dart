import 'package:fpdart/fpdart.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> register({
    required String email,
    required String password,
    required String role,
  });

  Future<Either<Failure, TokenPair>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, TokenPair>> refreshToken(String refreshToken);

  Future<Either<Failure, Unit>> logout(String refreshToken);

  Future<Either<Failure, User?>> getCachedUser();
}
