part of 'wallet_bloc.dart';

abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {
  const WalletInitial();
}

class WalletLoading extends WalletState {
  const WalletLoading();
}

class WalletLoaded extends WalletState {
  final Wallet wallet;
  final List<WalletTransaction> transactions;

  const WalletLoaded({required this.wallet, required this.transactions});

  @override
  List<Object?> get props => [wallet, transactions];
}

class WalletTopUpSuccess extends WalletState {
  final WalletTransaction transaction;
  final Wallet wallet;
  final List<WalletTransaction> transactions;

  const WalletTopUpSuccess({
    required this.transaction,
    required this.wallet,
    required this.transactions,
  });

  @override
  List<Object?> get props => [transaction, wallet, transactions];
}

class WalletError extends WalletState {
  final String message;

  const WalletError(this.message);

  @override
  List<Object?> get props => [message];
}
