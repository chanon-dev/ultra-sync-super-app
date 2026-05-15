import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/auth/domain/entities/user.dart';
import 'package:ultra_sync/features/auth/domain/repositories/auth_repository.dart';

@lazySingleton
class RegisterUseCase implements UseCase<User, RegisterParams> {
  final AuthRepository _repository;

  const RegisterUseCase(this._repository);

  @override
  Future<Either<Failure, User>> call(RegisterParams params) {
    return _repository.register(
      email: params.email,
      password: params.password,
      role: params.role,
    );
  }
}

class RegisterParams extends Equatable {
  final String email;
  final String password;
  final String role;

  const RegisterParams({
    required this.email,
    required this.password,
    this.role = 'user',
  });

  @override
  List<Object?> get props => [email, password, role];
}
