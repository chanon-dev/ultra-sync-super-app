import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                context.read<WalletBloc>().add(const WalletLoadRequested()),
          ),
        ],
      ),
      body: BlocConsumer<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is WalletTopUpSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Topped up ${state.transaction.amount} ${state.wallet.currency}'),
              backgroundColor: AppColors.secondary,
            ));
          }
          if (state is WalletError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
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
            return _WalletContent(
                wallet: wallet, transactions: transactions);
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

  const _WalletContent(
      {required this.wallet, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _BalanceCard(wallet: wallet),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Transaction History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        if (transactions.isEmpty)
          const SliverFillRemaining(child: _EmptyTransactions())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                  _TransactionCard(transaction: transactions[i]),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2744), Color(0xFF0D1B34)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.secondary.withOpacity(0.4)),
                ),
                child: Text(
                  wallet.currency,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.secondary, size: 28),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Available Balance',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatBalance(wallet.balance),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Top Up',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => _showTopUpSheet(context),
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
    final decimal = parts.length > 1 ? parts[1] : '0000';
    return '$integer.$decimal';
  }

  void _showTopUpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<WalletBloc>(),
        child: const _TopUpSheet(),
      ),
    );
  }
}

class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet();

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const _presets = ['100', '500', '1000', '5000'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                decoration: BoxDecoration(
                  color: AppColors.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Top Up Wallet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: _presets
                  .map((p) => ActionChip(
                        label: Text(p),
                        onPressed: () => _controller.text = p,
                        backgroundColor: AppColors.surfaceVariant,
                        labelStyle:
                            const TextStyle(color: AppColors.onBackground),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.onBackground),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'THB  ',
                prefixStyle: TextStyle(color: AppColors.onSurface),
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
              builder: (context, state) {
                final loading = state is WalletLoading;
                return ElevatedButton(
                  onPressed: loading ? null : () => _submit(context),
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Confirm Top Up'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_controller.text);
    final idempotencyKey =
        '${DateTime.now().millisecondsSinceEpoch}-${amount.toStringAsFixed(4)}';
    context.read<WalletBloc>().add(WalletTopUpRequested(
          amount: amount.toStringAsFixed(4),
          idempotencyKey: idempotencyKey,
        ));
    Navigator.of(context).pop();
  }
}

class _TransactionCard extends StatelessWidget {
  final WalletTransaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final color = isCredit ? AppColors.secondary : AppColors.error;
    final sign = isCredit ? '+' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon(transaction.type), color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.type.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onBackground,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    _formatDate(transaction.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurface,
                        ),
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
                Text(
                  'bal: ${transaction.balanceAfter}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurface,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(TransactionType type) => switch (type) {
        TransactionType.topup => Icons.arrow_downward_rounded,
        TransactionType.payment => Icons.shopping_bag_outlined,
        TransactionType.payout => Icons.arrow_upward_rounded,
      };

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
          const Icon(Icons.receipt_long_outlined,
              color: AppColors.onSurface, size: 56),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Top up your wallet to get started',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.onSurface),
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
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: AppColors.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
