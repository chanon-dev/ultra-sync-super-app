import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';

class WalletModel extends Wallet {
  const WalletModel({
    required super.userId,
    required super.balance,
    required super.currency,
    required super.version,
    required super.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      userId: json['user_id'] as String,
      balance: json['balance'] as String,
      currency: json['currency'] as String? ?? 'THB',
      version: json['version'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class TransactionModel extends WalletTransaction {
  const TransactionModel({
    required super.id,
    required super.walletId,
    required super.type,
    required super.amount,
    required super.balanceAfter,
    super.referenceId,
    required super.idempotencyKey,
    required super.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      type: TransactionType.fromString(json['type'] as String),
      amount: json['amount'] as String,
      balanceAfter: json['balance_after'] as String,
      referenceId: json['reference_id'] as String?,
      idempotencyKey: json['idempotency_key'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
