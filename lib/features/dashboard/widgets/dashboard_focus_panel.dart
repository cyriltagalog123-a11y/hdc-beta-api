import 'package:flutter/material.dart';

import '../../../core/ui/hdc_colors.dart';

class DashboardFocusPanel extends StatelessWidget {
  final int unreadNotifications;
  final int activeServices;
  final int newOffers;
  final bool hasPrivateWorkspace;
  final VoidCallback onNotifications;
  final VoidCallback onSuggestions;
  final VoidCallback onRatings;
  final VoidCallback? onPrivateOperations;

  const DashboardFocusPanel({
    required this.unreadNotifications,
    required this.activeServices,
    required this.newOffers,
    required this.hasPrivateWorkspace,
    required this.onNotifications,
    required this.onSuggestions,
    required this.onRatings,
    this.onPrivateOperations,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final attentionCount = unreadNotifications + newOffers;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HDCColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HDCColors.border),
        boxShadow: const [
          BoxShadow(
            color: HDCColors.shadowSoft,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: HDCColors.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: HDCColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attentionCount == 0
                              ? 'Your HDC workspace is clear'
                              : '$attentionCount update${attentionCount == 1 ? '' : 's'} may need attention',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$activeServices active service${activeServices == 1 ? '' : 's'} • $newOffers offer${newOffers == 1 ? '' : 's'} • $unreadNotifications unread notification${unreadNotifications == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: HDCColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FocusAction(
                icon: Icons.notifications_none_rounded,
                label: unreadNotifications == 0
                    ? 'Notifications'
                    : 'Notifications ($unreadNotifications)',
                onTap: onNotifications,
              ),
              _FocusAction(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Suggestions',
                onTap: onSuggestions,
              ),
              _FocusAction(
                icon: Icons.stars_outlined,
                label: 'Ratings & Badges',
                onTap: onRatings,
              ),
              if (hasPrivateWorkspace && onPrivateOperations != null)
                _FocusAction(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Private Operations',
                  onTap: onPrivateOperations!,
                  emphasized: true,
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 16),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 3, child: header),
              const SizedBox(width: 20),
              Expanded(flex: 4, child: Align(
                alignment: Alignment.centerRight,
                child: actions,
              )),
            ],
          );
        },
      ),
    );
  }
}

class _FocusAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  const _FocusAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    if (emphasized) {
      return FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
