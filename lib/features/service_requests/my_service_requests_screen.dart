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
import '../../providers/hdc_auth_provider.dart';
import '../../providers/hdc_workflow_sync_provider.dart';
import '../../providers/proposal_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/service_transaction_provider.dart';
import 'create_service_request_screen.dart';
import 'service_request_details_screen.dart';

enum _RequestView { all, active, offers, closed }

extension on _RequestView {
  String get label => switch (this) {
    _RequestView.all => 'All',
    _RequestView.active => 'Active',
    _RequestView.offers => 'With offers',
    _RequestView.closed => 'Closed',
  };
}

class MyServiceRequestsScreen extends StatefulWidget {
  const MyServiceRequestsScreen({super.key});

  @override
  State<MyServiceRequestsScreen> createState() =>
      _MyServiceRequestsScreenState();
}

class _MyServiceRequestsScreenState extends State<MyServiceRequestsScreen> {
  _RequestView _view = _RequestView.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(refreshHdcWorkflow(context));
    });
  }

  void _createRequest() {
    Navigator.of(
      context,
    ).push(HDCPageRoute<void>(page: const CreateServiceRequestScreen()));
  }

  List<ServiceRequest> _visibleRequests(
    List<ServiceRequest> requests,
    ProposalProvider proposals,
  ) {
    final filtered = requests.where((request) {
      return switch (_view) {
        _RequestView.all => true,
        _RequestView.active => request.status.isActive,
        _RequestView.offers =>
          proposals.summaryForRequest(request.id).received > 0,
        _RequestView.closed =>
          request.status == ServiceRequestStatus.completed ||
              request.status == ServiceRequestStatus.cancelled ||
              request.status == ServiceRequestStatus.expired,
      };
    });

    return [...filtered]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServiceRequestProvider>();
    final proposalProvider = context.watch<ProposalProvider>();
    final sync = context.watch<HdcWorkflowSyncProvider?>();
    final customerId = context.watch<HDCAuthProvider>().currentUserId;
    final requests = provider.requests
        .where((request) => request.customerId == customerId)
        .toList(growable: false);
    final visibleRequests = _visibleRequests(requests, proposalProvider);
    final isRefreshing =
        provider.isLoading ||
        proposalProvider.isLoading ||
        (sync?.isSyncing ?? false);
    final loadError =
        provider.lastError ?? proposalProvider.lastError ?? sync?.lastError;
    final activeCount = requests
        .where((request) => request.status.isActive)
        .length;
    final offerCount = requests
        .where(
          (request) =>
              proposalProvider.summaryForRequest(request.id).received > 0,
        )
        .length;
    final closedCount = requests
        .where(
          (request) =>
              request.status == ServiceRequestStatus.completed ||
              request.status == ServiceRequestStatus.cancelled ||
              request.status == ServiceRequestStatus.expired,
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Service Requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh requests',
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
        ],
      ),
      body: HDCSignalBackdrop(
        child: RefreshIndicator(
          onRefresh: () => refreshHdcWorkflow(context),
          child: ListView(
            key: const Key('hdc-customer-request-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              HDCSpacing.md,
              HDCSpacing.md,
              HDCSpacing.md,
              HDCSpacing.xxl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: HDCSpacing.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HDCFlowHero(
                        eyebrow: 'Customer request center',
                        title: 'Track every service request in one place',
                        description:
                            'Follow request status, incoming offers, and active '
                            'service work from the same verified record.',
                        icon: Icons.assignment_outlined,
                        tags: [
                          HDCFlowTag(
                            label: '$activeCount active',
                            icon: Icons.bolt_outlined,
                            color: HDCColors.signal,
                          ),
                          HDCFlowTag(
                            label: '$offerCount with offers',
                            icon: Icons.local_offer_outlined,
                            color: HDCColors.accent,
                          ),
                          HDCFlowTag(
                            label: '$closedCount closed',
                            icon: Icons.task_alt_outlined,
                            color: HDCColors.success,
                          ),
                        ],
                        action: FilledButton.icon(
                          key: const Key('hdc-new-service-request'),
                          onPressed: _createRequest,
                          icon: const Icon(Icons.add_task),
                          label: const Text('New Service Request'),
                        ),
                      ),
                      if (loadError != null && requests.isNotEmpty) ...[
                        const SizedBox(height: HDCSpacing.md),
                        _RequestSyncWarning(
                          onRetry: () => refreshHdcWorkflow(context),
                        ),
                      ],
                      const SizedBox(height: HDCSpacing.lg),
                      _RequestFilters(
                        selected: _view,
                        requests: requests,
                        proposals: proposalProvider,
                        onSelected: (view) => setState(() => _view = view),
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                      if (isRefreshing && requests.isEmpty)
                        const _RequestLoading()
                      else if (loadError != null && requests.isEmpty)
                        _RequestLoadError(
                          onRetry: () => refreshHdcWorkflow(context),
                        )
                      else if (requests.isEmpty)
                        HDCEmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'No service requests yet',
                          description:
                              'Create a request with the issue, location, '
                              'schedule, and budget. Approved technicians can '
                              'then review it and submit tracked offers.',
                          actions: [
                            FilledButton.icon(
                              onPressed: _createRequest,
                              icon: const Icon(Icons.add_task),
                              label: const Text('Post First Request'),
                            ),
                          ],
                        )
                      else if (visibleRequests.isEmpty)
                        HDCEmptyState(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'No requests in this view',
                          description:
                              'Your records are still available. Clear this '
                              'filter to see every service request.',
                          actions: [
                            OutlinedButton.icon(
                              onPressed: () => setState(
                                () => _view = _RequestView.all,
                              ),
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Show All Requests'),
                            ),
                          ],
                        )
                      else
                        _RequestGrid(requests: visibleRequests),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestFilters extends StatelessWidget {
  final _RequestView selected;
  final List<ServiceRequest> requests;
  final ProposalProvider proposals;
  final ValueChanged<_RequestView> onSelected;

  const _RequestFilters({
    required this.selected,
    required this.requests,
    required this.proposals,
    required this.onSelected,
  });

  int _count(_RequestView view) {
    return requests.where((request) {
      return switch (view) {
        _RequestView.all => true,
        _RequestView.active => request.status.isActive,
        _RequestView.offers =>
          proposals.summaryForRequest(request.id).received > 0,
        _RequestView.closed =>
          request.status == ServiceRequestStatus.completed ||
              request.status == ServiceRequestStatus.cancelled ||
              request.status == ServiceRequestStatus.expired,
      };
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      padding: const EdgeInsets.all(HDCSpacing.md),
      child: Wrap(
        spacing: HDCSpacing.xs,
        runSpacing: HDCSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: HDCSpacing.xs),
            child: Text(
              'View',
              style: TextStyle(
                color: HDCColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final view in _RequestView.values)
            ChoiceChip(
              key: Key('hdc-request-filter-${view.name}'),
              selected: view == selected,
              onSelected: (_) => onSelected(view),
              label: Text('${view.label}  ${_count(view)}'),
            ),
        ],
      ),
    );
  }
}

class _RequestGrid extends StatelessWidget {
  final List<ServiceRequest> requests;

  const _RequestGrid({required this.requests});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960 ? 2 : 1;
        final width = columns == 2
            ? (constraints.maxWidth - HDCSpacing.md) / 2
            : constraints.maxWidth;

        return Wrap(
          key: const Key('hdc-customer-request-results'),
          spacing: HDCSpacing.md,
          runSpacing: HDCSpacing.md,
          children: [
            for (final request in requests)
              SizedBox(width: width, child: _RequestCard(request: request)),
          ],
        );
      },
    );
  }
}

class _RequestLoading extends StatelessWidget {
  const _RequestLoading();

  @override
  Widget build(BuildContext context) {
    return const HDCCard(
      child: SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _RequestLoadError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _RequestLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return HDCEmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Service requests could not be loaded',
      description:
          'The existing records were not changed. Check the connection and '
          'try loading your request center again.',
      color: HDCColors.danger,
      actions: [
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
        ),
      ],
    );
  }
}

class _RequestSyncWarning extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _RequestSyncWarning({required this.onRetry});

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
              'Some offer or request updates may be delayed. The records '
              'shown here were not changed.',
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

class _RequestCard extends StatelessWidget {
  final ServiceRequest request;

  const _RequestCard({required this.request});

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

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<ProposalProvider>().summaryForRequest(
      request.id,
    );
    final transaction = context.watch<ServiceTransactionProvider>().forRequest(
      request.id,
    );

    return HDCCard(
      key: Key('hdc-request-card-${request.id}'),
      onTap: () {
        Navigator.of(context).push(
          HDCPageRoute<void>(
            page: ServiceRequestDetailsScreen(requestId: request.id),
          ),
        );
      },
      elevated: summary.received > 0 || transaction != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: HDCColors.secondary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.home_repair_service_outlined,
                  color: HDCColors.secondary,
                ),
              ),
              const SizedBox(width: HDCSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      request.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HDCSpacing.xs),
              const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: HDCSpacing.md),
          Wrap(
            spacing: HDCSpacing.xs,
            runSpacing: HDCSpacing.xs,
            children: [
              HDCStatusBadge(
                label: request.status.label,
                tone: _requestStatusTone(request.status),
                icon: _requestStatusIcon(request.status),
              ),
              if (summary.received > 0)
                HDCStatusBadge(
                  label: summary.received == 1
                      ? '1 offer'
                      : '${summary.received} offers',
                  tone: HDCStatusTone.info,
                  icon: Icons.local_offer_outlined,
                ),
              if (transaction != null)
                HDCStatusBadge(
                  label: transaction.status.label,
                  tone: HDCStatusTone.success,
                  icon: Icons.handshake_outlined,
                ),
            ],
          ),
          const SizedBox(height: HDCSpacing.md),
          _RequestFact(
            icon: Icons.location_on_outlined,
            label: request.location,
          ),
          const SizedBox(height: HDCSpacing.xs),
          _RequestFact(
            icon: Icons.event_outlined,
            label:
                '${_dateLabel(request.preferredDate)} • ${request.preferredTime}',
          ),
          const SizedBox(height: HDCSpacing.xs),
          _RequestFact(
            icon: Icons.payments_outlined,
            label: request.budgetLabel,
          ),
          if (summary.viewedOrBeyond > 0 || summary.shortlisted > 0) ...[
            const SizedBox(height: HDCSpacing.md),
            Wrap(
              spacing: HDCSpacing.md,
              runSpacing: HDCSpacing.xs,
              children: [
                if (summary.viewedOrBeyond > 0)
                  _SmallMetric(
                    icon: Icons.visibility_outlined,
                    label: '${summary.viewedOrBeyond} viewed',
                  ),
                if (summary.shortlisted > 0)
                  _SmallMetric(
                    icon: Icons.favorite_outline,
                    label: '${summary.shortlisted} shortlisted',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestFact extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RequestFact({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: HDCColors.textSecondary),
        const SizedBox(width: HDCSpacing.xs),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallMetric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: HDCColors.secondary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
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
