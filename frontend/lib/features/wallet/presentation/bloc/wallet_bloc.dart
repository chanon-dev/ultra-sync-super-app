import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/get_balance_usecase.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/list_transactions_usecase.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/top_up_usecase.dart';
import 'package:ultra_sync/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:ultra_sync/features/wallet/presentation/bloc/wallet_state.dart';

@injectable
class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final GetBalanceUseCase _getBalance;
  final TopUpUseCase _topUp;
  final ListTransactionsUseCase _listTransactions;

  WalletBloc({
    required GetBalanceUseCase getBalance,
    required TopUpUseCase topUp,
    required ListTransactionsUseCase listTransactions,
  })  : _getBalance = getBalance,
        _topUp = topUp,
        _listTransactions = listTransactions,
        super(const WalletInitial()) {
    on<WalletLoadRequested>(_onLoad);
    on<WalletTopUpRequested>(_onTopUp);
  }

  Future<void> _onLoad(
    WalletLoadRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());
    final balanceResult = await _getBalance(const NoParams());
    if (balanceResult.isLeft()) {
      return emit(WalletError(balanceResult.getLeft().toNullable()!.message));
    }
    final wallet = balanceResult.getRight().toNullable()!;

    final txResult = await _listTransactions(const ListTransactionsParams());
    final transactions = txResult.getRight().toNullable() ?? const <WalletTransaction>[];

    emit(WalletLoaded(wallet: wallet, transactions: transactions));
  }

  Future<void> _onTopUp(
    WalletTopUpRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());

    final topUpResult = await _topUp(TopUpParams(
      amount: event.amount,
      idempotencyKey: event.idempotencyKey,
    ));
    if (topUpResult.isLeft()) {
      return emit(WalletError(topUpResult.getLeft().toNullable()!.message));
    }
    final tx = topUpResult.getRight().toNullable()!;

    final balanceResult = await _getBalance(const NoParams());
    if (balanceResult.isLeft()) {
      return emit(WalletError(balanceResult.getLeft().toNullable()!.message));
    }
    final wallet = balanceResult.getRight().toNullable()!;

    final txResult = await _listTransactions(const ListTransactionsParams());
    final transactions = txResult.getRight().toNullable() ?? const <WalletTransaction>[];

    emit(WalletLoaded(
      wallet: wallet,
      transactions: transactions,
      topUpJustSucceeded: true,
      lastTopUp: tx,
    ));
  }
}
