import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';

@freezed
abstract class Wallet with _$Wallet {
  const factory Wallet({
    required String userId,
    required String balance,
    required String currency,
    required int version,
    required DateTime updatedAt,
  }) = _Wallet;
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

@freezed
abstract class WalletTransaction with _$WalletTransaction {
  const WalletTransaction._();

  const factory WalletTransaction({
    required String id,
    required String walletId,
    required TransactionType type,
    required String amount,
    required String balanceAfter,
    String? referenceId,
    required String idempotencyKey,
    required DateTime createdAt,
  }) = _WalletTransaction;

  bool get isCredit => !amount.startsWith('-');
}
