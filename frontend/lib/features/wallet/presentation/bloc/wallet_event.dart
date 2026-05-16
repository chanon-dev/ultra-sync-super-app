part of 'wallet_bloc.dart';

abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

class WalletLoadRequested extends WalletEvent {
  const WalletLoadRequested();
}

class WalletTopUpRequested extends WalletEvent {
  final String amount;
  final String idempotencyKey;

  const WalletTopUpRequested({
    required this.amount,
    required this.idempotencyKey,
  });

  @override
  List<Object?> get props => [amount, idempotencyKey];
}
