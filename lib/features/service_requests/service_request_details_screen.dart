import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_brand.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';
import '../../core/ui/hdc_status_badge.dart';
import '../../core/workflow/hdc_workflow_refresh.dart';
import '../../models/service_request.dart';
import '../../models/service_transaction.dart';
import '../../providers/hdc_workflow_sync_provider.dart';
import '../../providers/proposal_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/service_transaction_provider.dart';
import '../../widgets/proposals/request_proposal_activity_card.dart';
import '../customer_proposals/customer_proposal_inbox_screen.dart';
import '../transactions/service_transaction_workspace_screen.dart';
import 'create_service_request_screen.dart';

class ServiceRequestDetailsScreen extends StatefulWidget {
  final String requestId;
  final bool justPublished;

  const ServiceRequestDetailsScreen({
    required this.requestId,
    this.justPublished = false,
    super.key,
  });

  @override
  State<ServiceRequestDetailsScreen> createState() =>
      _ServiceRequestDetailsScreenState();
}

class _ServiceRequestDetailsScreenState
    extends State<ServiceRequestDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(refreshHdcWorkflow(context));
    });
  }

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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _edit(ServiceRequest request) {
    Navigator.of(context).push(
      HDCPageRoute<void>(
        page: CreateServiceRequestScreen(existingRequest: request),
      ),
    );
  }

  void _reviewProposals(ServiceRequest request) {
    Navigator.of(context).push(
      HDCPageRoute<void>(
        page: CustomerProposalInboxScreen(request: request),
      ),
    );
  }

  void _openWorkspace(
    ServiceRequest request,
    ServiceTransaction transaction,
  ) {
    Navigator.of(context).push(
      HDCPageRoute<void>(
        page: ServiceTransactionWorkspaceScreen(
          transactionId: transaction.id,
          actorId: request.customerId,
          role: ServiceTransactionParticipantRole.customer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<HdcWorkflowSyncProvider?>();
    final proposalProvider = context.watch<ProposalProvider>();
    final isRefreshing =
        (sync?.isSyncing ?? false) || proposalProvider.isLoading;
    final refreshError = sync?.lastError ?? proposalProvider.lastError;
    final request = context.select<ServiceRequestProvider, ServiceRequest?>(
      (provider) => provider.byId(widget.requestId),
    );
    final proposalSummary = proposalProvider.summaryForRequest(
      widget.requestId,
    );

    if (request == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Request Details'),
          actions: [
            IconButton(
              tooltip: 'Refresh request',
              onPressed: isRefreshing
                  ? null
                  : () => refreshHdcWorkflow(context),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: HDCSignalBackdrop(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(HDCSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: isRefreshing
                    ? const HDCCard(
                        child: SizedBox(
                          height: 180,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    : HDCEmptyState(
                        icon: Icons.search_off_outlined,
                        title: 'Service request not found',
                        description:
                            'The request may not be available to this account, '
                            'or the latest records have not loaded yet.',
                        actions: [
                          FilledButton.icon(
                            onPressed: () => refreshHdcWorkflow(context),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
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
          IconButton(
            tooltip: 'Refresh request',
            onPressed: isRefreshing
                ? null
                : () => refreshHdcWorkflow(context),
            icon: isRefreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          if (request.status.canEdit)
            IconButton(
              tooltip: 'Edit request',
              onPressed: () => _edit(request),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: HDCSignalBackdrop(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            HDCSpacing.md,
            HDCSpacing.md,
            HDCSpacing.md,
            HDCSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: HDCSpacing.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.justPublished) ...[
                    const _PublishedNotice(),
                    const SizedBox(height: HDCSpacing.md),
                  ],
                  if (refreshError != null) ...[
                    _RecordSyncWarning(
                      onRetry: () => refreshHdcWorkflow(context),
                    ),
                    const SizedBox(height: HDCSpacing.md),
                  ],
                  HDCFlowHero(
                    eyebrow: 'Customer request record',
                    title: request.title,
                    description:
                        'Review the issue, compare every tracked offer, and '
                        'continue into the service workspace after acceptance.',
                    icon: Icons.assignment_outlined,
                    tags: [
                      HDCFlowTag(
                        label: request.status.label,
                        icon: _requestStatusIcon(request.status),
                        color: _requestStatusColor(request.status),
                      ),
                      HDCFlowTag(
                        label: request.categoryName,
                        icon: Icons.category_outlined,
                        color: HDCColors.accent,
                      ),
                      HDCFlowTag(
                        label: request.urgency.label,
                        icon: Icons.priority_high,
                        color: request.urgency ==
                                ServiceRequestUrgency.emergency
                            ? HDCColors.danger
                            : HDCColors.warning,
                      ),
                    ],
                    action: request.status.canEdit
                        ? FilledButton.tonalIcon(
                            key: const Key('hdc-request-details-edit'),
                            onPressed: () => _edit(request),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit Request'),
                          )
                        : null,
                  ),
                  const SizedBox(height: HDCSpacing.lg),
                  _RequestMetrics(
                    offerCount: proposalSummary.received,
                    viewedCount: proposalSummary.viewedOrBeyond,
                    shortlistedCount: proposalSummary.shortlisted,
                    transaction: transaction,
                  ),
                  const SizedBox(height: HDCSpacing.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 1020;
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _RequestInformation(
                            request: request,
                            dateLabel: _dateLabel,
                          ),
                          const SizedBox(height: HDCSpacing.md),
                          _NexusInsight(
                            insight: proposalProvider.customerNexusInsight(
                              request.id,
                            ),
                          ),
                          const SizedBox(height: HDCSpacing.md),
                          RequestProposalActivityCard(
                            entries: proposalActivity,
                          ),
                        ],
                      );
                      final actions = _RequestActions(
                        request: request,
                        transaction: transaction,
                        offerCount: proposalSummary.received,
                        onReviewProposals: () => _reviewProposals(request),
                        onOpenWorkspace: transaction == null
                            ? null
                            : () => _openWorkspace(request, transaction),
                        onCancel: request.status.isActive
                            ? () => _cancel(context, request)
                            : null,
                      );

                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            actions,
                            const SizedBox(height: HDCSpacing.md),
                            details,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: HDCSpacing.lg),
                          SizedBox(width: 360, child: actions),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublishedNotice extends StatelessWidget {
  const _PublishedNotice();

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      key: const Key('hdc-request-published-notice'),
      color: HDCColors.success.withValues(alpha: 0.07),
      borderColor: HDCColors.success.withValues(alpha: 0.24),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: HDCColors.success),
          SizedBox(width: HDCSpacing.sm),
          Expanded(
            child: Text(
              'Your service request is open and ready for technician offers.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordSyncWarning extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _RecordSyncWarning({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      color: HDCColors.warning.withValues(alpha: 0.07),
      borderColor: HDCColors.warning.withValues(alpha: 0.24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sync_problem, color: HDCColors.warning),
          const SizedBox(width: HDCSpacing.sm),
          const Expanded(
            child: Text(
              'The latest offer or service update may be delayed. No request '
              'record was changed by this loading error.',
              style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: HDCSpacing.xs),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _RequestMetrics extends StatelessWidget {
  final int offerCount;
  final int viewedCount;
  final int shortlistedCount;
  final ServiceTransaction? transaction;

  const _RequestMetrics({
    required this.offerCount,
    required this.viewedCount,
    required this.shortlistedCount,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1020
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - (columns - 1) * HDCSpacing.sm) / columns;

        return Wrap(
          key: const Key('hdc-request-details-metrics'),
          spacing: HDCSpacing.sm,
          runSpacing: HDCSpacing.sm,
          children: [
            SizedBox(
              width: width,
              child: HDCMetricTile(
                icon: Icons.local_offer_outlined,
                label: 'Offers received',
                value: '$offerCount',
              ),
            ),
            SizedBox(
              width: width,
              child: HDCMetricTile(
                icon: Icons.visibility_outlined,
                label: 'Viewed',
                value: '$viewedCount',
                color: HDCColors.info,
              ),
            ),
            SizedBox(
              width: width,
              child: HDCMetricTile(
                icon: Icons.favorite_outline,
                label: 'Shortlisted',
                value: '$shortlistedCount',
                color: HDCColors.warning,
              ),
            ),
            SizedBox(
              width: width,
              child: HDCMetricTile(
                icon: Icons.handshake_outlined,
                label: 'Service workspace',
                value: transaction?.status.label ?? 'Not active yet',
                color: transaction == null
                    ? HDCColors.textSecondary
                    : HDCColors.success,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RequestInformation extends StatelessWidget {
  final ServiceRequest request;
  final String Function(DateTime) dateLabel;

  const _RequestInformation({
    required this.request,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return HDCSectionCard(
      title: 'Request information',
      subtitle: 'The published issue details technicians use for their offers.',
      trailing: HDCStatusBadge(
        label: request.status.label,
        tone: _requestStatusTone(request.status),
        icon: _requestStatusIcon(request.status),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.description,
            style: const TextStyle(height: 1.6),
          ),
          const SizedBox(height: HDCSpacing.lg),
          const Divider(),
          const SizedBox(height: HDCSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 620 ? 2 : 1;
              final width = columns == 2
                  ? (constraints.maxWidth - HDCSpacing.sm) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: HDCSpacing.sm,
                runSpacing: HDCSpacing.sm,
                children: [
                  SizedBox(
                    width: width,
                    child: _RequestDetail(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: request.location,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _RequestDetail(
                      icon: Icons.event_outlined,
                      label: 'Preferred schedule',
                      value:
                          '${dateLabel(request.preferredDate)} • ${request.preferredTime}',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _RequestDetail(
                      icon: Icons.payments_outlined,
                      label: 'Budget',
                      value: request.budgetLabel,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _RequestDetail(
                      icon: Icons.priority_high,
                      label: 'Urgency',
                      value: request.urgency.label,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _RequestDetail(
                      icon: Icons.update_outlined,
                      label: 'Last updated',
                      value: dateLabel(request.updatedAt),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _RequestDetail(
                      icon: Icons.fingerprint,
                      label: 'Request reference',
                      value: request.id,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RequestDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RequestDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HDCSpacing.md),
      decoration: BoxDecoration(
        color: HDCColors.background,
        borderRadius: BorderRadius.circular(HDCSpacing.radiusSmall),
        border: Border.all(color: HDCColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: HDCColors.secondary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: HDCColors.secondary, size: 19),
          ),
          const SizedBox(width: HDCSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: HDCColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestActions extends StatelessWidget {
  final ServiceRequest request;
  final ServiceTransaction? transaction;
  final int offerCount;
  final VoidCallback onReviewProposals;
  final VoidCallback? onOpenWorkspace;
  final VoidCallback? onCancel;

  const _RequestActions({
    required this.request,
    required this.transaction,
    required this.offerCount,
    required this.onReviewProposals,
    required this.onOpenWorkspace,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('hdc-request-details-actions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionPanel(
          icon: Icons.mark_email_unread_outlined,
          color: HDCColors.secondary,
          title: offerCount == 1
              ? '1 professional offer'
              : '$offerCount professional offers',
          description:
              'Review technician assessments, pricing, schedules, warranties, '
              'and reputation before accepting.',
          action: FilledButton.icon(
            key: const Key('hdc-request-review-offers'),
            onPressed: onReviewProposals,
            icon: const Icon(Icons.inbox_outlined),
            label: const Text('Review All Offers'),
          ),
        ),
        if (transaction != null) ...[
          const SizedBox(height: HDCSpacing.md),
          _ActionPanel(
            icon: Icons.handshake_outlined,
            color: HDCColors.success,
            title: 'Service workspace ready',
            description:
                '${transaction!.status.label} • ${transaction!.id}',
            action: FilledButton.icon(
              key: const Key('hdc-request-open-workspace'),
              onPressed: onOpenWorkspace,
              icon: const Icon(Icons.work_outline),
              label: const Text('Open Workspace'),
            ),
          ),
        ],
        const SizedBox(height: HDCSpacing.md),
        HDCSectionCard(
          title: 'What happens next?',
          child: Text(
            _nextStepText(request.status, transaction),
            style: const TextStyle(
              color: HDCColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        if (onCancel != null) ...[
          const SizedBox(height: HDCSpacing.md),
          OutlinedButton.icon(
            key: const Key('hdc-request-cancel'),
            onPressed: onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel Request'),
          ),
        ],
      ],
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final Widget action;

  const _ActionPanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      elevated: true,
      borderColor: color.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color),
            ),
          ),
          const SizedBox(height: HDCSpacing.md),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: HDCSpacing.md),
          SizedBox(width: double.infinity, child: action),
        ],
      ),
    );
  }
}

class _NexusInsight extends StatelessWidget {
  final String insight;

  const _NexusInsight({required this.insight});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      color: HDCColors.secondary.withValues(alpha: 0.05),
      borderColor: HDCColors.secondary.withValues(alpha: 0.20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.smart_toy_outlined, color: HDCColors.secondary),
          const SizedBox(width: HDCSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nexus Request Insight',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(
                  insight,
                  style: const TextStyle(
                    color: HDCColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _nextStepText(
  ServiceRequestStatus status,
  ServiceTransaction? transaction,
) {
  if (transaction != null) {
    return 'An offer has been accepted. Open the service workspace to '
        'coordinate work, chat, documents, payments, and any dispute record.';
  }
  if (status == ServiceRequestStatus.cancelled) {
    return 'This request is cancelled and is no longer visible to technicians.';
  }
  if (status == ServiceRequestStatus.completed) {
    return 'This request is complete. Its details and proposal activity remain '
        'available as part of the transaction record.';
  }
  if (status == ServiceRequestStatus.expired) {
    return 'This request has expired. Create a new request if the service is '
        'still needed.';
  }
  return 'Technicians can submit structured professional offers. Review each '
      'offer and shortlist the strongest options before acceptance.';
}

HDCStatusTone _requestStatusTone(ServiceRequestStatus status) {
  return switch (status) {
    ServiceRequestStatus.draft => HDCStatusTone.neutral,
    ServiceRequestStatus.open => HDCStatusTone.info,
    ServiceRequestStatus.receivingOffers => HDCStatusTone.warning,
    ServiceRequestStatus.technicianSelected => HDCStatusTone.success,
    ServiceRequestStatus.inProgress => HDCStatusTone.success,
    ServiceRequestStatus.completed => HDCStatusTone.success,
    ServiceRequestStatus.cancelled => HDCStatusTone.danger,
    ServiceRequestStatus.expired => HDCStatusTone.neutral,
  };
}

Color _requestStatusColor(ServiceRequestStatus status) {
  return switch (_requestStatusTone(status)) {
    HDCStatusTone.neutral => HDCColors.textSecondary,
    HDCStatusTone.info => HDCColors.info,
    HDCStatusTone.success => HDCColors.success,
    HDCStatusTone.warning => HDCColors.warning,
    HDCStatusTone.danger => HDCColors.danger,
  };
}

IconData _requestStatusIcon(ServiceRequestStatus status) {
  return switch (status) {
    ServiceRequestStatus.draft => Icons.edit_note_outlined,
    ServiceRequestStatus.open => Icons.campaign_outlined,
    ServiceRequestStatus.receivingOffers => Icons.mark_email_unread_outlined,
    ServiceRequestStatus.technicianSelected => Icons.person_pin_outlined,
    ServiceRequestStatus.inProgress => Icons.build_circle_outlined,
    ServiceRequestStatus.completed => Icons.task_alt_outlined,
    ServiceRequestStatus.cancelled => Icons.cancel_outlined,
    ServiceRequestStatus.expired => Icons.timer_off_outlined,
  };
}
