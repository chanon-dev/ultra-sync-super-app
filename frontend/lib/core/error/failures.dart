import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String code;

  const Failure({required this.message, required this.code});

  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code = 'SRV-001'});
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection', super.code = 'NET-001'});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'Session expired', super.code = 'AUTH-001'});
}

class ValidationFailure extends Failure {
  final List<FieldError> details;

  const ValidationFailure({
    required super.message,
    super.code = 'VAL-001',
    this.details = const [],
  });

  @override
  List<Object?> get props => [message, code, details];
}

class FieldError extends Equatable {
  final String field;
  final String issue;

  const FieldError({required this.field, required this.issue});

  @override
  List<Object?> get props => [field, issue];
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Cache error', super.code = 'CACHE-001'});
}
