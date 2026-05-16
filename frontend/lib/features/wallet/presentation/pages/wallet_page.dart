import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';
import 'package:ultra_sync/features/wallet/domain/entities/wallet.dart';
import 'package:ultra_sync/features/wallet/presentation/bloc/wallet_bloc.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const WalletLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is WalletTopUpSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Topped up ${state.transaction.amount} ${state.wallet.currency}'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
          }
          if (state is WalletError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.secondary));
          }
          if (state is WalletLoaded || state is WalletTopUpSuccess) {
            final wallet = state is WalletLoaded
                ? state.wallet
                : (state as WalletTopUpSuccess).wallet;
            final transactions = state is WalletLoaded
                ? state.transactions
                : (state as WalletTopUpSuccess).transactions;
            return _WalletContent(wallet: wallet, transactions: transactions);
          }
          if (state is WalletError) {
            return _ErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<WalletBloc>().add(const WalletLoadRequested()),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _WalletContent extends StatelessWidget {
  final Wallet wallet;
  final List<WalletTransaction> transactions;

  const _WalletContent({required this.wallet, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _BalanceCard(wallet: wallet),
                ),
                const SizedBox(height: 20),
                _ActionRow(wallet: wallet),
                const SizedBox(height: 28),
                const _ListHeader(),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        if (transactions.isEmpty)
          const SliverFillRemaining(child: _EmptyTransactions())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList.separated(
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _TransactionCard(transaction: transactions[i]),
            ),
          ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final Wallet wallet;
  const _BalanceCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppGradients.walletCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  wallet.currency,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Available Balance',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatBalance(wallet.balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Wallet ID: ${wallet.userId.substring(0, 8)}...',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _formatBalance(String raw) {
    final parts = raw.split('.');
    final integer = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    final decimal = parts.length > 1 ? parts[1].substring(0, 2) : '00';
    return '$integer.$decimal';
  }
}

class _ActionRow extends StatelessWidget {
  final Wallet wallet;
  const _ActionRow({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.add_rounded,
              label: 'Top Up',
              gradient: AppGradients.secondary,
              onTap: () => _showTopUpSheet(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan & Pay',
              onTap: () => context.push('/wallet/scan'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              icon: Icons.qr_code_rounded,
              label: 'Receive',
              onTap: () => context.push('/wallet/qr'),
            ),
          ),
        ],
      ),
    );
  }

  void _showTopUpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<WalletBloc>(),
        child: const _TopUpSheet(),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient? gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? AppColors.surfaceVariant : null,
          borderRadius: BorderRadius.circular(14),
          border: gradient == null ? Border.all(color: AppColors.divider) : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: gradient != null ? Colors.white : AppColors.onBackground,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: gradient != null ? Colors.white : AppColors.onBackground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Transactions',
            style: TextStyle(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.onSurface, size: 20),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final WalletTransaction transaction;
  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final color = isCredit ? AppColors.success : AppColors.error;
    final sign = isCredit ? '+' : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_typeIcon(transaction.type), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.type.label,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(transaction.createdAt),
                  style: const TextStyle(color: AppColors.onSurface, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${transaction.amount}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'bal: ${transaction.balanceAfter}',
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(TransactionType type) => switch (type) {
        TransactionType.topup => Icons.arrow_downward_rounded,
        TransactionType.payment => Icons.shopping_bag_outlined,
        TransactionType.payout => Icons.arrow_upward_rounded,
      };

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet();

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  static const _presets = ['100', '500', '1,000', '5,000'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Top Up Wallet',
              style: TextStyle(
                color: AppColors.onBackground,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets
                  .map((p) => GestureDetector(
                        onTap: () =>
                            _controller.text = p.replaceAll(',', ''),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Text(
                            'THB $p',
                            style: const TextStyle(
                              color: AppColors.onBackground,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: AppColors.onBackground, fontSize: 18, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'THB  ',
                prefixStyle:
                    TextStyle(color: AppColors.onSurface, fontSize: 15),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter an amount';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 24),
            BlocBuilder<WalletBloc, WalletState>(
              builder: (context, state) => ElevatedButton(
                onPressed:
                    state is WalletLoading ? null : () => _submit(context),
                child: state is WalletLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.black),
                      )
                    : const Text('Confirm Top Up'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_controller.text);
    final key = '${DateTime.now().millisecondsSinceEpoch}-${amount.toStringAsFixed(4)}';
    context.read<WalletBloc>().add(WalletTopUpRequested(
          amount: amount.toStringAsFixed(4),
          idempotencyKey: key,
        ));
    Navigator.of(context).pop();
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.onSurface, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'No transactions yet',
            style: TextStyle(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Top up your wallet to get started',
            style: TextStyle(color: AppColors.onSurface, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: AppColors.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
              width: 140, child: ElevatedButton(onPressed: onRetry, child: const Text('Retry'))),
        ],
      ),
    );
  }
}
