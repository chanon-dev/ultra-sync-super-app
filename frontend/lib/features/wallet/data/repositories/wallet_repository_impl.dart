import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/wallet/data/datasources/wallet_remote_data_source.dart';
import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';
import 'package:ultra_sync/features/wallet/domain/repositories/wallet_repository.dart';

@LazySingleton(as: WalletRepository)
class WalletRepositoryImpl implements WalletRepository {
  final WalletRemoteDataSource _remote;

  WalletRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, Wallet>> getBalance() async {
    try {
      final model = await _remote.getBalance();
      return Right(model.toDomain());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, WalletTransaction>> topUp({
    required String amount,
    required String idempotencyKey,
  }) async {
    try {
      final model = await _remote.topUp(amount: amount, idempotencyKey: idempotencyKey);
      return Right(model.toDomain());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<WalletTransaction>>> listTransactions({
    String? type,
    String? after,
    int limit = 20,
  }) async {
    try {
      final models = await _remote.listTransactions(type: type, after: after, limit: limit);
      return Right(models.map((m) => m.toDomain()).toList());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
