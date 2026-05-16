import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';
import 'package:ultra_sync/features/wallet/domain/repositories/wallet_repository.dart';

@lazySingleton
class ListTransactionsUseCase
    implements UseCase<List<WalletTransaction>, ListTransactionsParams> {
  final WalletRepository _repository;

  const ListTransactionsUseCase(this._repository);

  @override
  Future<Either<Failure, List<WalletTransaction>>> call(
      ListTransactionsParams params) {
    return _repository.listTransactions(
      type: params.type,
      after: params.after,
      limit: params.limit,
    );
  }
}

class ListTransactionsParams extends Equatable {
  final String? type;
  final String? after;
  final int limit;

  const ListTransactionsParams({this.type, this.after, this.limit = 20});

  @override
  List<Object?> get props => [type, after, limit];
}
