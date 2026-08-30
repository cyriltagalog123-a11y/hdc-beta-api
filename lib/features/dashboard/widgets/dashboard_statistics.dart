import 'package:flutter/material.dart';

import '../../../core/ui/hdc_colors.dart';

class DashboardStatistics extends StatelessWidget {
  final int openRequestCount;
  final int activeServiceCount;
  final int offerCount;
  final int completedServiceCount;
  final bool guestMode;

  const DashboardStatistics({
    this.openRequestCount = 0,
    this.activeServiceCount = 0,
    this.offerCount = 0,
    this.completedServiceCount = 0,
    this.guestMode = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (guestMode) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              const Icon(Icons.visibility_outlined, color: HDCColors.info),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Account statistics are hidden in Guest mode. Sign in or '
                  'register to see your requests, offers, and service history.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: HDCColors.textSecondary, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = [
      _StatisticData(
        value: '$openRequestCount',
        label: 'Open Requests',
        icon: Icons.campaign_outlined,
        color: HDCColors.info,
      ),
      _StatisticData(
        value: '$offerCount',
        label: 'New Offers',
        icon: Icons.local_offer_outlined,
        color: HDCColors.warning,
      ),
      _StatisticData(
        value: '$activeServiceCount',
        label: 'Active Services',
        icon: Icons.handshake_outlined,
        color: HDCColors.primary,
      ),
      _StatisticData(
        value: '$completedServiceCount',
        label: 'Completed Services',
        icon: Icons.check_circle_outline,
        color: HDCColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _StatisticCard(data: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatisticData {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatisticData({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _StatisticCard extends StatelessWidget {
  final _StatisticData data;

  const _StatisticCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: data.color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.label,
                    style: const TextStyle(
                      color: HDCColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
