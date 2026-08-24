import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/service_request.dart';
import '../../providers/proposal_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/service_transaction_provider.dart';
import '../../widgets/proposals/request_proposal_activity_card.dart';
import '../customer_proposals/customer_proposal_inbox_screen.dart';
import '../transactions/service_transaction_workspace_screen.dart';
import '../../models/service_transaction.dart';
import 'create_service_request_screen.dart';

class ServiceRequestDetailsScreen extends StatelessWidget {
  final String requestId;
  final bool justPublished;

  const ServiceRequestDetailsScreen({
    required this.requestId,
    this.justPublished = false,
    super.key,
  });

  Future<void> _cancel(
    BuildContext context,
    ServiceRequest request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text(
          'Technicians will no longer be able to view or send offers for it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Request'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<ServiceRequestProvider>().cancel(request.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service request cancelled.')),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The request could not be cancelled.'),
        ),
      );
    }
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final request = context.select<ServiceRequestProvider, ServiceRequest?>(
      (provider) => provider.byId(requestId),
    );
    final proposalProvider = context.watch<ProposalProvider>();
    final proposalSummary = proposalProvider.summaryForRequest(requestId);

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: const Center(child: Text('This service request was not found.')),
      );
    }

    final proposalActivity = proposalProvider.activityForRequest(request);
    final transaction = context
        .watch<ServiceTransactionProvider>()
        .forRequest(request.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        actions: [
          if (request.status.canEdit)
            IconButton(
              tooltip: 'Edit request',
              onPressed: () {
                Navigator.of(context).push(
                  HDCPageRoute<void>(
                    page: CreateServiceRequestScreen(
                      existingRequest: request,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (justPublished) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: HDCColors.success.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: HDCColors.success.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: HDCColors.success),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your service request is now open and ready for '
                              'technician offers.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 9,
                            runSpacing: 9,
                            children: [
                              _StatusBadge(status: request.status),
                              _SimpleBadge(label: request.categoryName),
                              _SimpleBadge(label: request.urgency.label),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            request.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            request.id,
                            style: const TextStyle(
                              color: HDCColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            request.description,
                            style: const TextStyle(height: 1.6),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final columns = width >= 650 ? 2 : 1;
                              final itemWidth = columns == 2
                                  ? (width - 14) / 2
                                  : width;
                              return Wrap(
                                spacing: 14,
                                runSpacing: 14,
                                children: [
                                  _InfoCard(
                                    width: itemWidth,
                                    icon: Icons.location_on_outlined,
                                    label: 'Location',
                                    value: request.location,
                                  ),
                                  _InfoCard(
                                    width: itemWidth,
                                    icon: Icons.event_outlined,
                                    label: 'Schedule',
                                    value:
                                        '${_dateLabel(request.preferredDate)} • '
                                        '${request.preferredTime}',
                                  ),
                                  _InfoCard(
                                    width: itemWidth,
                                    icon: Icons.payments_outlined,
                                    label: 'Budget',
                                    value: request.budgetLabel,
                                  ),
                                  _InfoCard(
                                    width: itemWidth,
                                    icon: Icons.local_offer_outlined,
                                    label: 'Offers received',
                                    value: '${proposalSummary.received}',
                                  ),
                                  _InfoCard(
                                    width: itemWidth,
                                    icon: Icons.visibility_outlined,
                                    label: 'Viewed',
                                    value: '${proposalSummary.viewedOrBeyond}',
                                  ),
                                  _InfoCard(
                                    width: itemWidth,
                                    icon: Icons.favorite_outline,
                                    label: 'Shortlisted',
                                    value: '${proposalSummary.shortlisted}',
                                  ),
                                  _InfoCard(
                                    width: itemWidth,
                                    icon: Icons.update_outlined,
                                    label: 'Last updated',
                                    value: _dateLabel(request.updatedAt),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: HDCColors.secondary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.mark_email_unread_outlined,
                              color: HDCColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  proposalSummary.received == 1
                                      ? '1 professional proposal received'
                                      : '${proposalSummary.received} professional proposals received',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Review technician assessments, pricing, schedules, warranties, and reputation.',
                                  style: TextStyle(
                                    color: HDCColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                HDCPageRoute<void>(
                                  page: CustomerProposalInboxScreen(
                                    request: request,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.inbox_outlined),
                            label: const Text('Review Proposals'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (transaction != null) ...[
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.handshake_outlined,
                              color: HDCColors.success,
                              size: 30,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Service Workspace Ready',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${transaction.status.label} • ${transaction.id}',
                                    style: const TextStyle(
                                      color: HDCColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  HDCPageRoute<void>(
                                    page: ServiceTransactionWorkspaceScreen(
                                      transactionId: transaction.id,
                                      actorId: request.customerId,
                                      role: ServiceTransactionParticipantRole.customer,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.work_outline),
                              label: const Text('Open Workspace'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.smart_toy_outlined,
                            color: HDCColors.secondary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nexus Request Insight',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  proposalProvider.customerNexusInsight(
                                    request.id,
                                  ),
                                  style: const TextStyle(
                                    color: HDCColors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  RequestProposalActivityCard(
                    entries: proposalActivity,
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: HDCColors.info,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'What happens next?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  request.status ==
                                          ServiceRequestStatus.cancelled
                                      ? 'This request is cancelled and is no '
                                          'longer visible to technicians.'
                                      : 'Technicians can submit structured professional proposals. Review each proposal carefully and shortlist the strongest options before comparison.',
                                  style: const TextStyle(
                                    color: HDCColors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (request.status.isActive) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _cancel(context, request),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel Request'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ServiceRequestStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == ServiceRequestStatus.cancelled
        ? HDCColors.danger
        : HDCColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SimpleBadge extends StatelessWidget {
  final String label;
  const _SimpleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: HDCColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HDCColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HDCColors.background,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: HDCColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: HDCColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: HDCColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
