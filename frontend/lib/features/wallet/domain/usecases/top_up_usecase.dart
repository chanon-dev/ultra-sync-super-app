import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';
import 'package:ultra_sync/features/wallet/domain/repositories/wallet_repository.dart';

@lazySingleton
class TopUpUseCase implements UseCase<WalletTransaction, TopUpParams> {
  final WalletRepository _repository;

  const TopUpUseCase(this._repository);

  @override
  Future<Either<Failure, WalletTransaction>> call(TopUpParams params) {
    return _repository.topUp(
      amount: params.amount,
      idempotencyKey: params.idempotencyKey,
    );
  }
}

class TopUpParams extends Equatable {
  final String amount;
  final String idempotencyKey;

  const TopUpParams({required this.amount, required this.idempotencyKey});

  @override
  List<Object?> get props => [amount, idempotencyKey];
}
