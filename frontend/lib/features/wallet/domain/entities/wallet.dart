import 'package:equatable/equatable.dart';

class Wallet extends Equatable {
  final String userId;
  final String balance;
  final String currency;
  final int version;
  final DateTime updatedAt;

  const Wallet({
    required this.userId,
    required this.balance,
    required this.currency,
    required this.version,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [userId, balance, currency, version, updatedAt];
}

enum TransactionType {
  topup,
  payment,
  payout;

  String get label => switch (this) {
        topup => 'Top Up',
        payment => 'Payment',
        payout => 'Payout',
      };

  static TransactionType fromString(String s) => switch (s) {
        'topup' => topup,
        'payment' => payment,
        'payout' => payout,
        _ => topup,
      };
}

class WalletTransaction extends Equatable {
  final String id;
  final String walletId;
  final TransactionType type;
  final String amount;
  final String balanceAfter;
  final String? referenceId;
  final String idempotencyKey;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.referenceId,
    required this.idempotencyKey,
    required this.createdAt,
  });

  bool get isCredit => !amount.startsWith('-');

  @override
  List<Object?> get props => [id, type, amount, createdAt];
}
