import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';

class WalletModel {
  final String userId;
  final String balance;
  final String currency;
  final int version;
  final DateTime updatedAt;

  const WalletModel({
    required this.userId,
    required this.balance,
    required this.currency,
    required this.version,
    required this.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
        userId: json['user_id'] as String,
        balance: json['balance'] as String,
        currency: json['currency'] as String? ?? 'THB',
        version: json['version'] as int? ?? 0,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Wallet toDomain() => Wallet(
        userId: userId,
        balance: balance,
        currency: currency,
        version: version,
        updatedAt: updatedAt,
      );
}

class TransactionModel {
  final String id;
  final String walletId;
  final TransactionType type;
  final String amount;
  final String balanceAfter;
  final String? referenceId;
  final String idempotencyKey;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.referenceId,
    required this.idempotencyKey,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
        id: json['id'] as String,
        walletId: json['wallet_id'] as String,
        type: TransactionType.fromString(json['type'] as String),
        amount: json['amount'] as String,
        balanceAfter: json['balance_after'] as String,
        referenceId: json['reference_id'] as String?,
        idempotencyKey: json['idempotency_key'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  WalletTransaction toDomain() => WalletTransaction(
        id: id,
        walletId: walletId,
        type: type,
        amount: amount,
        balanceAfter: balanceAfter,
        referenceId: referenceId,
        idempotencyKey: idempotencyKey,
        createdAt: createdAt,
      );
}
