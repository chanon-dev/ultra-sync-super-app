import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_event.freezed.dart';

@freezed
sealed class WalletEvent with _$WalletEvent {
  const factory WalletEvent.loadRequested() = WalletLoadRequested;

  const factory WalletEvent.topUpRequested({
    required String amount,
    required String idempotencyKey,
  }) = WalletTopUpRequested;
}
