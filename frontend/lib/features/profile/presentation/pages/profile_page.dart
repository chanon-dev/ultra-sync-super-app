import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';
import 'package:ultra_sync/features/auth/presentation/bloc/auth_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(child: _AccountSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: _PreferencesSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _DangerSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.primary,
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 44),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider, width: 2),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: AppColors.onSurface, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Ultra-Sync User',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Member since 2025',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 20),
          _StatsRow(),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatChip(value: '24', label: 'Shipments'),
          _Divider(),
          _StatChip(value: '5', label: 'Active'),
          _Divider(),
          _StatChip(value: '4.9★', label: 'Rating'),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.divider);
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.onSurface, fontSize: 12),
        ),
      ],
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Account',
      items: const [
        _SettingItem(
          icon: Icons.person_outline_rounded,
          label: 'Personal Information',
          trailing: true,
        ),
        _SettingItem(
          icon: Icons.security_rounded,
          label: 'Security & Password',
          trailing: true,
        ),
        _SettingItem(
          icon: Icons.fingerprint_rounded,
          label: 'Biometric Login',
          trailing: true,
        ),
        _SettingItem(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          trailing: true,
        ),
      ],
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      title: 'App Settings',
      items: [
        _SettingItem(
          icon: Icons.language_rounded,
          label: 'Language',
          value: 'English',
          trailing: true,
        ),
        _SettingItem(
          icon: Icons.dark_mode_outlined,
          label: 'Theme',
          value: 'Dark',
          trailing: true,
        ),
        _SettingItem(
          icon: Icons.help_outline_rounded,
          label: 'Help & Support',
          trailing: true,
        ),
        _SettingItem(
          icon: Icons.info_outline_rounded,
          label: 'About Ultra-Sync',
          value: 'v1.0.0',
          trailing: true,
        ),
      ],
    );
  }
}

class _DangerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Account Actions'),
          const SizedBox(height: 12),
          _LogoutTile(),
        ],
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => _LogoutDialog(authBloc: context.read<AuthBloc>()),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
                SizedBox(width: 14),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  final AuthBloc authBloc;
  const _LogoutDialog({required this.authBloc});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divider),
      ),
      title: const Text(
        'Sign Out?',
        style: TextStyle(color: AppColors.onBackground, fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'You will need to sign in again to access your account.',
        style: TextStyle(color: AppColors.onSurface),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.onSurface)),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            authBloc.add(const AuthLogoutRequested());
          },
          child: const Text('Sign Out',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_SettingItem> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: items.asMap().entries.map((e) {
                final isLast = e.key == items.length - 1;
                return Column(
                  children: [
                    e.value,
                    if (!isLast)
                      const Divider(height: 1, indent: 52),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool trailing;
  const _SettingItem({
    required this.icon,
    required this.label,
    this.value,
    this.trailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (value != null) ...[
                Text(
                  value!,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (trailing)
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.onSurface, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
