import 'package:equatable/equatable.dart';

/// Dart 3 sealed class — subclasses must live in this file.
/// Exhaustive switch is enforced by the compiler; [message] and [code]
/// are accessible on the base type without a cast.
sealed class Failure extends Equatable {
  final String message;
  final String code;

  const Failure({required this.message, required this.code});

  @override
  List<Object?> get props => [message, code];
}

final class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code = 'SRV-001'});
}

final class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection',
    super.code = 'NET-001',
  });
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    super.message = 'Session expired',
    super.code = 'AUTH-001',
  });
}

final class ValidationFailure extends Failure {
  final List<FieldError> details;

  const ValidationFailure({
    required super.message,
    super.code = 'VAL-001',
    this.details = const [],
  });

  @override
  List<Object?> get props => [message, code, details];
}

final class FieldError extends Equatable {
  final String field;
  final String issue;

  const FieldError({required this.field, required this.issue});

  @override
  List<Object?> get props => [field, issue];
}

final class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Cache error',
    super.code = 'CACHE-001',
  });
}
