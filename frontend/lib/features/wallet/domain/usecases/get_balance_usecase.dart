import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';
import 'package:ultra_sync/features/wallet/domain/repositories/wallet_repository.dart';

@lazySingleton
class GetBalanceUseCase implements UseCase<Wallet, NoParams> {
  final WalletRepository _repository;

  const GetBalanceUseCase(this._repository);

  @override
  Future<Either<Failure, Wallet>> call(NoParams params) {
    return _repository.getBalance();
  }
}
