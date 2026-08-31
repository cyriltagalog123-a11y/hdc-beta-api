import 'package:flutter/material.dart';

import '../../../core/ui/hdc_colors.dart';
import '../../../core/ui/hdc_spacing.dart';

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
    final actions = [
      _PrimaryActionData(
        index: '01',
        eyebrow: 'REQUEST',
        icon: Icons.add_task_rounded,
        title: 'Post a Service Request',
        subtitle:
            'Describe the issue once and receive tracked technician offers.',
        color: HDCColors.accent,
        emphasized: true,
        onTap: onPostRequest,
      ),
      _PrimaryActionData(
        index: '02',
        eyebrow: 'DISCOVER',
        icon: Icons.manage_search_rounded,
        title: 'Find a Technician',
        subtitle: 'Search public skills, specialties, and service areas.',
        color: HDCColors.signal,
        onTap: onFindTechnician,
      ),
      _PrimaryActionData(
        index: '03',
        eyebrow: 'MARKET',
        icon: Icons.shopping_bag_outlined,
        title: 'Shop Technology',
        subtitle: 'Browse items and send a tracked purchase request.',
        color: HDCColors.warm,
        onTap: onShopTechnology,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 940) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < actions.length; index += 1) ...[
                  if (index > 0) const SizedBox(width: 16),
                  Expanded(child: _PrimaryActionCard(data: actions[index])),
                ],
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < actions.length; index += 1) ...[
              if (index > 0) const SizedBox(height: 14),
              _PrimaryActionCard(data: actions[index]),
            ],
          ],
        );
      },
    );
  }
}

class _PrimaryActionData {
  final String index;
  final String eyebrow;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool emphasized;
  final VoidCallback onTap;

  const _PrimaryActionData({
    required this.index,
    required this.eyebrow,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.emphasized = false,
  });
}

class _PrimaryActionCard extends StatelessWidget {
  final _PrimaryActionData data;

  const _PrimaryActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final foreground = data.emphasized
        ? HDCColors.textLight
        : HDCColors.textPrimary;
    final secondaryText = data.emphasized
        ? HDCColors.textLight.withValues(alpha: 0.70)
        : HDCColors.textSecondary;
    final radius = BorderRadius.circular(HDCSpacing.radiusMedium);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: data.emphasized ? null : HDCColors.surface,
        gradient: data.emphasized ? HDCColors.brandGradient : null,
        borderRadius: radius,
        border: Border.all(
          color: data.emphasized
              ? HDCColors.accent.withValues(alpha: 0.28)
              : HDCColors.border,
        ),
        boxShadow: data.emphasized
            ? const [
                BoxShadow(
                  color: HDCColors.shadow,
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: data.onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 188),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: data.color.withValues(
                          alpha: data.emphasized ? 0.16 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: data.color.withValues(alpha: 0.26),
                        ),
                      ),
                      child: Icon(data.icon, color: data.color, size: 23),
                    ),
                    const Spacer(),
                    Text(
                      data.index,
                      style: TextStyle(
                        color: data.color.withValues(alpha: 0.72),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  data.eyebrow,
                  style: TextStyle(
                    color: data.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.25,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  data.title,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.subtitle,
                  style: TextStyle(color: secondaryText, height: 1.45),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'OPEN WORKFLOW',
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.76),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, color: foreground),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
