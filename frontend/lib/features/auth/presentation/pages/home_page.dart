import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            const SliverToBoxAdapter(child: _QuickStats()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            const SliverToBoxAdapter(child: _SectionTitle('Services')),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(child: _ServicesGrid()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            const SliverToBoxAdapter(child: _SectionTitle('Quick Actions')),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            const SliverToBoxAdapter(child: _QuickActions()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ultra-Sync',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.onBackground,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _NotificationButton(),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Icon(Icons.notifications_outlined,
              color: AppColors.onBackground, size: 22),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppGradients.walletCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.primary,
        ),
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                label: 'Wallet Balance',
                value: 'THB 12,500',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: AppColors.secondary,
              ),
            ),
            Container(
              width: 1,
              height: 48,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            Expanded(
              child: _StatItem(
                label: 'Active Shipments',
                value: '3 orders',
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.primaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid();

  @override
  Widget build(BuildContext context) {
    const cards = [
      _ServiceData(
        icon: Icons.local_shipping_outlined,
        label: 'Logistics',
        subtitle: 'Track & ship packages',
        gradient: AppGradients.logistics,
        route: '/logistics',
        comingSoon: false,
      ),
      _ServiceData(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Wallet',
        subtitle: 'Manage your money',
        gradient: AppGradients.secondary,
        route: '/wallet',
        comingSoon: false,
      ),
      _ServiceData(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Chat',
        subtitle: 'Real-time messaging',
        gradient: AppGradients.primary,
        route: '',
        comingSoon: true,
      ),
      _ServiceData(
        icon: Icons.bar_chart_rounded,
        label: 'Analytics',
        subtitle: 'Reports & insights',
        gradient: AppGradients.wallet,
        route: '',
        comingSoon: true,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 0.95,
      children: cards
          .map((c) => _ServiceCard(
                data: c,
                onTap: c.comingSoon || c.route.isEmpty
                    ? null
                    : () => context.push(c.route),
              ))
          .toList(),
    );
  }
}

class _ServiceData {
  final IconData icon;
  final String label;
  final String subtitle;
  final LinearGradient gradient;
  final String route;
  final bool comingSoon;

  const _ServiceData({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.route,
    required this.comingSoon,
  });
}

class _ServiceCard extends StatelessWidget {
  final _ServiceData data;
  final VoidCallback? onTap;

  const _ServiceCard({required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: data.comingSoon ? null : data.gradient,
                    color: data.comingSoon ? AppColors.surfaceVariant : null,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    data.icon,
                    color: data.comingSoon ? AppColors.onSurface : Colors.white,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Text(
                  data.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: data.comingSoon
                            ? AppColors.onSurface
                            : AppColors.onBackground,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.comingSoon ? 'Coming soon' : data.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurface,
                        fontSize: 11,
                      ),
                ),
                if (data.comingSoon) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Soon',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              icon: Icons.add_box_outlined,
              label: 'New Shipment',
              onTap: () => context.go('/logistics/create'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionTile(
              icon: Icons.qr_code_rounded,
              label: 'Receive Pay',
              onTap: () => context.go('/wallet/qr'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionTile(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan & Pay',
              onTap: () => context.go('/wallet/scan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.onBackground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
