import 'package:flutter/material.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/proposal_activity_entry.dart';

class RequestProposalActivityCard extends StatelessWidget {
  final List<ProposalActivityEntry> entries;

  const RequestProposalActivityCard({
    required this.entries,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final visible = entries.take(8).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Important proposal activity for this service request.',
              style: TextStyle(
                color: HDCColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            if (visible.isEmpty)
              const Text(
                'No activity recorded yet.',
                style: TextStyle(color: HDCColors.textSecondary),
              )
            else
              for (var index = 0; index < visible.length; index++)
                _ActivityRow(
                  entry: visible[index],
                  showLine: index != visible.length - 1,
                ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ProposalActivityEntry entry;
  final bool showLine;

  const _ActivityRow({
    required this.entry,
    required this.showLine,
  });

  @override
  Widget build(BuildContext context) {
    final details = _details(entry.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: details.color.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    details.icon,
                    color: details.color,
                    size: 18,
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: HDCColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _timeLabel(entry.timestamp),
                        style: const TextStyle(
                          color: HDCColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.description,
                    style: const TextStyle(
                      color: HDCColors.textSecondary,
                      height: 1.4,
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

  _ActivityVisual _details(ProposalActivityType type) {
    switch (type) {
      case ProposalActivityType.requestCreated:
        return const _ActivityVisual(
          icon: Icons.campaign_outlined,
          color: HDCColors.info,
        );
      case ProposalActivityType.proposalSubmitted:
        return const _ActivityVisual(
          icon: Icons.mark_email_unread_outlined,
          color: HDCColors.warning,
        );
      case ProposalActivityType.proposalViewed:
        return const _ActivityVisual(
          icon: Icons.visibility_outlined,
          color: HDCColors.secondary,
        );
      case ProposalActivityType.proposalShortlisted:
        return const _ActivityVisual(
          icon: Icons.favorite_outline,
          color: Colors.deepPurple,
        );
      case ProposalActivityType.proposalAccepted:
        return const _ActivityVisual(
          icon: Icons.check_circle_outline,
          color: HDCColors.success,
        );
      case ProposalActivityType.proposalDeclined:
        return const _ActivityVisual(
          icon: Icons.remove_circle_outline,
          color: HDCColors.danger,
        );
      case ProposalActivityType.proposalWithdrawn:
        return const _ActivityVisual(
          icon: Icons.undo_outlined,
          color: HDCColors.textSecondary,
        );
    }
  }

  String _timeLabel(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${time.month}/${time.day}/${time.year}';
  }
}

class _ActivityVisual {
  final IconData icon;
  final Color color;

  const _ActivityVisual({
    required this.icon,
    required this.color,
  });
}
