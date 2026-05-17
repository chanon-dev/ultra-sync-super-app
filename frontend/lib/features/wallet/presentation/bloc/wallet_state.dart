import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';

part 'wallet_state.freezed.dart';

@freezed
sealed class WalletState with _$WalletState {
  const factory WalletState.initial() = WalletInitial;
  const factory WalletState.loading() = WalletLoading;
  const factory WalletState.loaded({
    required Wallet wallet,
    required List<WalletTransaction> transactions,
    // When true, the listener in WalletPage shows a success snackbar once.
    @Default(false) bool topUpJustSucceeded,
    WalletTransaction? lastTopUp,
  }) = WalletLoaded;
  const factory WalletState.error(String message) = WalletError;
}
