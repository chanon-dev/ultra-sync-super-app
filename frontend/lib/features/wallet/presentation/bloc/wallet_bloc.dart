import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/get_balance_usecase.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/list_transactions_usecase.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/top_up_usecase.dart';

part 'wallet_event.dart';
part 'wallet_state.dart';

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
    await balanceResult.fold(
      (f) async => emit(WalletError(f.message)),
      (wallet) async {
        final txResult =
            await _listTransactions(const ListTransactionsParams());
        txResult.fold(
          (_) => emit(WalletLoaded(wallet: wallet, transactions: const [])),
          (txs) => emit(WalletLoaded(wallet: wallet, transactions: txs)),
        );
      },
    );
  }

  Future<void> _onTopUp(
    WalletTopUpRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());
    final result = await _topUp(TopUpParams(
      amount: event.amount,
      idempotencyKey: event.idempotencyKey,
    ));
    await result.fold(
      (f) async => emit(WalletError(f.message)),
      (tx) async {
        final balanceResult = await _getBalance(const NoParams());
        await balanceResult.fold(
          (f) async => emit(WalletError(f.message)),
          (wallet) async {
            final txResult =
                await _listTransactions(const ListTransactionsParams());
            txResult.fold(
              (_) => emit(WalletTopUpSuccess(
                  transaction: tx, wallet: wallet, transactions: const [])),
              (txs) => emit(WalletTopUpSuccess(
                  transaction: tx, wallet: wallet, transactions: txs)),
            );
          },
        );
      },
    );
  }
}
