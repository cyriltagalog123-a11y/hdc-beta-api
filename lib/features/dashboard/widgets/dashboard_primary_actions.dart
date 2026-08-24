import 'package:flutter/material.dart';

import '../../../core/ui/hdc_colors.dart';

class DashboardPrimaryActions extends StatelessWidget {
  final VoidCallback onPostRequest;
  final VoidCallback onFindTechnician;
  final VoidCallback onShopTechnology;

  const DashboardPrimaryActions({
    required this.onPostRequest,
    required this.onFindTechnician,
    required this.onShopTechnology,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 980;

        final postRequest = _PrimaryActionCard(
          icon: Icons.add_task,
          title: 'Post a Service Request',
          subtitle:
              'Describe the work and receive offers from technicians.',
          primary: true,
          onTap: onPostRequest,
        );

        final findTechnician = _PrimaryActionCard(
          icon: Icons.search,
          title: 'Find a Technician',
          subtitle:
              'Browse verified professionals and book directly.',
          primary: false,
          onTap: onFindTechnician,
        );

        final shopTechnology = _PrimaryActionCard(
          icon: Icons.shopping_bag_outlined,
          title: 'Shop Technology',
          subtitle: 'Browse items and send tracked purchase requests.',
          primary: false,
          onTap: onShopTechnology,
        );

        if (horizontal) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: postRequest,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: findTechnician,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: shopTechnology,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            postRequest,
            const SizedBox(height: 14),
            findTechnician,
            const SizedBox(height: 14),
            shopTechnology,
          ],
        );
      },
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;

  const _PrimaryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = primary
        ? HDCColors.secondary
        : HDCColors.surface;

    final foreground = primary
        ? Colors.white
        : HDCColors.textPrimary;

    final secondaryText = primary
        ? Colors.white.withValues(alpha: 0.82)
        : HDCColors.textSecondary;

    final iconBackground = primary
        ? Colors.white.withValues(alpha: 0.15)
        : HDCColors.secondary.withValues(alpha: 0.10);

    final iconColor = primary
        ? Colors.white
        : HDCColors.secondary;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 148,
          ),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: primary
                ? null
                : Border.all(
                    color: HDCColors.border,
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward,
                color: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
