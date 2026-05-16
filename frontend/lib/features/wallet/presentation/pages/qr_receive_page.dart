import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';
import 'package:ultra_sync/features/wallet/presentation/bloc/wallet_bloc.dart';

/// Displays the user's wallet QR code so another user can scan it
/// and send a payment.  The QR payload is the user's UUID which the
/// scanner uses to pre-fill a top-up / pay form.
class QrReceivePage extends StatelessWidget {
  const QrReceivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Payment')),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          final walletId = switch (state) {
            WalletLoaded s => s.wallet.userId,
            WalletTopUpSuccess s => s.wallet.userId,
            _ => null,
          };

          if (walletId == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            );
          }

          return _QrContent(walletId: walletId);
        },
      ),
    );
  }
}

class _QrContent extends StatelessWidget {
  final String walletId;
  const _QrContent({required this.walletId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'Scan to Pay Me',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Show this code to the payer',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.2),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: QrImageView(
              data: walletId,
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0D1B34),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0D1B34),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    walletId,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      color: AppColors.secondary, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: walletId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Wallet ID copied'),
                        backgroundColor: AppColors.secondary,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
