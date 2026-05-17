import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/utils/use_case.dart';
import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/get_balance_usecase.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/list_transactions_usecase.dart';
import 'package:ultra_sync/features/wallet/domain/usecases/top_up_usecase.dart';
import 'package:ultra_sync/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:ultra_sync/features/wallet/presentation/bloc/wallet_state.dart';

class _MockGetBalance extends Mock implements GetBalanceUseCase {}
class _MockTopUp extends Mock implements TopUpUseCase {}
class _MockListTransactions extends Mock implements ListTransactionsUseCase {}

void main() {
  late _MockGetBalance getBalance;
  late _MockTopUp topUp;
  late _MockListTransactions listTransactions;

  final tWallet = Wallet(
    userId: 'user-1',
    balance: '1000.0000',
    currency: 'THB',
    version: 1,
    updatedAt: DateTime(2024),
  );

  final tTx = WalletTransaction(
    id: 'tx-1',
    walletId: 'user-1',
    type: TransactionType.topup,
    amount: '100.0000',
    balanceAfter: '1100.0000',
    idempotencyKey: 'key-1',
    createdAt: DateTime(2024),
  );

  WalletBloc buildBloc() => WalletBloc(
        getBalance: getBalance,
        topUp: topUp,
        listTransactions: listTransactions,
      );

  setUp(() {
    getBalance = _MockGetBalance();
    topUp = _MockTopUp();
    listTransactions = _MockListTransactions();
    registerFallbackValue(const NoParams());
    registerFallbackValue(const ListTransactionsParams());
    registerFallbackValue(const TopUpParams(amount: '', idempotencyKey: ''));
  });

  group('WalletLoadRequested', () {
    blocTest<WalletBloc, WalletState>(
      'emits [Loading, Loaded] on success',
      build: () {
        when(() => getBalance(any())).thenAnswer((_) async => Right(tWallet));
        when(() => listTransactions(any())).thenAnswer((_) async => Right([tTx]));
        return buildBloc();
      },
      act: (b) => b.add(const WalletLoadRequested()),
      expect: () => [
        const WalletLoading(),
        WalletLoaded(wallet: tWallet, transactions: [tTx]),
      ],
    );

    blocTest<WalletBloc, WalletState>(
      'emits [Loading, Loaded] with empty transactions when listTransactions fails',
      build: () {
        when(() => getBalance(any())).thenAnswer((_) async => Right(tWallet));
        when(() => listTransactions(any()))
            .thenAnswer((_) async => const Left(NetworkFailure()));
        return buildBloc();
      },
      act: (b) => b.add(const WalletLoadRequested()),
      expect: () => [
        const WalletLoading(),
        WalletLoaded(wallet: tWallet, transactions: const []),
      ],
    );

    blocTest<WalletBloc, WalletState>(
      'emits [Loading, Error] when getBalance fails',
      build: () {
        when(() => getBalance(any()))
            .thenAnswer((_) async => const Left(NetworkFailure()));
        return buildBloc();
      },
      act: (b) => b.add(const WalletLoadRequested()),
      expect: () => [
        const WalletLoading(),
        isA<WalletError>(),
      ],
    );
  });

  group('WalletTopUpRequested', () {
    blocTest<WalletBloc, WalletState>(
      'emits [Loading, TopUpSuccess] on success',
      build: () {
        when(() => topUp(any())).thenAnswer((_) async => Right(tTx));
        when(() => getBalance(any())).thenAnswer((_) async => Right(tWallet));
        when(() => listTransactions(any())).thenAnswer((_) async => Right([tTx]));
        return buildBloc();
      },
      act: (b) => b.add(const WalletTopUpRequested(
        amount: '100.0000',
        idempotencyKey: 'key-1',
      )),
      expect: () => [
        const WalletLoading(),
        WalletLoaded(
          wallet: tWallet,
          transactions: [tTx],
          topUpJustSucceeded: true,
          lastTopUp: tTx,
        ),
      ],
    );

    blocTest<WalletBloc, WalletState>(
      'emits [Loading, Error] when topUp fails',
      build: () {
        when(() => topUp(any())).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'insufficient balance')),
        );
        return buildBloc();
      },
      act: (b) => b.add(const WalletTopUpRequested(
        amount: '9999.0000',
        idempotencyKey: 'key-fail',
      )),
      expect: () => [
        const WalletLoading(),
        const WalletError('insufficient balance'),
      ],
    );

    blocTest<WalletBloc, WalletState>(
      'emits [Loading, TopUpSuccess] with empty transactions when list fails after topup',
      build: () {
        when(() => topUp(any())).thenAnswer((_) async => Right(tTx));
        when(() => getBalance(any())).thenAnswer((_) async => Right(tWallet));
        when(() => listTransactions(any()))
            .thenAnswer((_) async => const Left(NetworkFailure()));
        return buildBloc();
      },
      act: (b) => b.add(const WalletTopUpRequested(
        amount: '100.0000',
        idempotencyKey: 'key-2',
      )),
      expect: () => [
        const WalletLoading(),
        WalletLoaded(
          wallet: tWallet,
          transactions: const [],
          topUpJustSucceeded: true,
          lastTopUp: tTx,
        ),
      ],
    );
  });
}
