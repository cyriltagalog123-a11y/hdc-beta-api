import 'package:flutter/material.dart';

import '../../../core/ui/hdc_colors.dart';

class DashboardServiceOverview extends StatelessWidget {
  final int activeTransactionCount;
  final int activeRequestCount;
  final int offerCount;
  final VoidCallback onViewTransactions;
  final VoidCallback onPostRequest;
  final VoidCallback onFindTechnician;
  final VoidCallback onViewOffers;
  final VoidCallback onViewRequests;

  const DashboardServiceOverview({
    required this.activeTransactionCount,
    required this.activeRequestCount,
    required this.offerCount,
    required this.onViewTransactions,
    required this.onPostRequest,
    required this.onFindTechnician,
    required this.onViewOffers,
    required this.onViewRequests,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasCurrentWork =
        activeTransactionCount > 0 || activeRequestCount > 0 || offerCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 50,
              margin: const EdgeInsets.only(top: 2, right: 12),
              decoration: BoxDecoration(
                color: hasCurrentWork ? HDCColors.signal : HDCColors.borderStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasCurrentWork ? 'CURRENT WORK' : 'WORKSPACE STATUS',
                    style: const TextStyle(
                      color: HDCColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hasCurrentWork
                        ? 'Continue what already needs your attention.'
                        : 'No active service work is waiting on this account.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Counts below come from your loaded HDC requests, offers, and service transactions.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (activeTransactionCount > 0) ...[
          _OverviewCard(
            icon: Icons.handshake_outlined,
            iconColor: HDCColors.success,
            title: 'Active Service Workspaces',
            statusLabel: '$activeTransactionCount ACTIVE',
            description:
                'Track accepted technology service work, participants, terms, and progress.',
            actionLabel: 'Open Workspaces',
            onAction: onViewTransactions,
            emphasized: true,
          ),
          const SizedBox(height: 16),
        ],
        _OverviewCard(
          icon: Icons.campaign_outlined,
          iconColor: HDCColors.info,
          title: 'Open Service Requests',
          statusLabel: activeRequestCount == 0
              ? 'NO OPEN REQUESTS'
              : '$activeRequestCount OPEN',
          description: activeRequestCount == 0
              ? 'Post a request to describe the technology service you need.'
              : 'You have $activeRequestCount active service '
                  '${activeRequestCount == 1 ? 'request' : 'requests'} awaiting '
                  'technician activity.',
          actionLabel:
              activeRequestCount == 0 ? 'Post a Request' : 'View Requests',
          onAction:
              activeRequestCount == 0 ? onPostRequest : onViewRequests,
        ),
        const SizedBox(height: 16),
        _OverviewCard(
          icon: Icons.local_offer_outlined,
          iconColor: HDCColors.warning,
          title: 'Offers Received',
          statusLabel: offerCount == 0 ? 'NO NEW OFFERS' : '$offerCount OFFERS',
          description: offerCount == 0
              ? 'Technician proposals appear here after a request is published.'
              : 'Compare professional technician proposals and choose the right match.',
          actionLabel: offerCount == 0 ? 'Find Technician' : 'Review Offers',
          onAction: offerCount == 0 ? onFindTechnician : onViewOffers,
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String statusLabel;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;
  final bool emphasized;

  const _OverviewCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.statusLabel,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: emphasized
              ? Border(left: BorderSide(color: iconColor, width: 4))
              : null,
        ),
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: iconColor.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: const TextStyle(
                      color: HDCColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(actionLabel),
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
