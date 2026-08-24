import 'package:flutter/material.dart';

import '../../../core/ui/hdc_colors.dart';

class DashboardQuickAccess extends StatelessWidget {
  final VoidCallback onTransactions;
  final VoidCallback onTickets;
  final VoidCallback onMarketplace;
  final VoidCallback onPassport;
  final VoidCallback onRoleCenter;
  final bool canAccessMarketplace;

  const DashboardQuickAccess({
    required this.onTransactions,
    required this.onTickets,
    required this.onMarketplace,
    required this.onPassport,
    required this.onRoleCenter,
    required this.canAccessMarketplace,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickAccessItem(
        icon: Icons.handshake_outlined,
        title: 'Active Services',
        subtitle: 'Open your transaction workspaces',
        onTap: onTransactions,
      ),
      _QuickAccessItem(
        icon: Icons.confirmation_number_outlined,
        title: 'My Tickets',
        subtitle: 'Track service activity',
        onTap: onTickets,
      ),
      if (canAccessMarketplace)
        _QuickAccessItem(
          icon: Icons.storefront_outlined,
          title: 'Technician Marketplace',
          subtitle: 'Browse open technology service requests',
          onTap: onMarketplace,
        ),
      _QuickAccessItem(
        icon: Icons.badge_outlined,
        title: 'HDC Passport',
        subtitle: 'Manage technology assets and records',
        onTap: onPassport,
      ),
      _QuickAccessItem(
        icon: Icons.switch_account_outlined,
        title: 'Role Center',
        subtitle: 'Buyer, technician, seller, store',
        onTap: onRoleCenter,
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Access',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Everything important is one step away.',
              style: TextStyle(
                color: HDCColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QuickAccessTile(item: item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _QuickAccessTile extends StatelessWidget {
  final _QuickAccessItem item;

  const _QuickAccessTile({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HDCColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HDCColors.secondary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  item.icon,
                  color: HDCColors.secondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: HDCColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
