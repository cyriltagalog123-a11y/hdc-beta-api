import 'package:flutter/material.dart';

import '../../../core/ui/hdc_colors.dart';

class DashboardActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime occurredAt;

  const DashboardActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
  });
}

class DashboardActivityTimeline extends StatelessWidget {
  final bool guestMode;
  final List<DashboardActivityItem> entries;

  const DashboardActivityTimeline({
    this.guestMode = false,
    this.entries = const <DashboardActivityItem>[],
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              guestMode
                  ? 'Sign in to see activity belonging to your HDC account.'
                  : 'Your latest service and account updates.',
              style: const TextStyle(color: HDCColors.textSecondary),
            ),
            const SizedBox(height: 22),
            if (entries.isEmpty)
              _EmptyActivity(guestMode: guestMode)
            else
              for (var index = 0; index < entries.length; index += 1)
                _TimelineEntry(
                  entry: entries[index],
                  time: _relativeTime(entries[index].occurredAt),
                  showLine: index < entries.length - 1,
                ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime value) {
    final now = DateTime.now();
    final localValue = value.toLocal();
    final difference = now.difference(localValue);
    if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${localValue.month}/${localValue.day}/${localValue.year}';
  }
}

class _EmptyActivity extends StatelessWidget {
  final bool guestMode;

  const _EmptyActivity({required this.guestMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: HDCColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HDCColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: HDCColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              guestMode
                  ? 'Guest mode has no account activity.'
                  : 'No activity yet. New requests, proposals, bookings, and '
                      'service updates will appear here.',
              style: const TextStyle(
                color: HDCColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final DashboardActivityItem entry;
  final String time;
  final bool showLine;

  const _TimelineEntry({
    required this.entry,
    required this.time,
    required this.showLine,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: entry.color.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(entry.icon, size: 20, color: entry.color),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: HDCColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          entry.subtitle,
                          style: const TextStyle(
                            color: HDCColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    time,
                    style: const TextStyle(
                      color: HDCColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
