import 'package:fpdart/fpdart.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';

abstract class WalletRepository {
  Future<Either<Failure, Wallet>> getBalance();

  Future<Either<Failure, WalletTransaction>> topUp({
    required String amount,
    required String idempotencyKey,
  });

  Future<Either<Failure, List<WalletTransaction>>> listTransactions({
    String? type,
    String? after,
    int limit = 20,
  });
}
