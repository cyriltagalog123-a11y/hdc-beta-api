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
import '../../models/service_transaction.dart';
import '../../providers/hdc_workflow_sync_provider.dart';
import '../../providers/service_transaction_provider.dart';
import 'service_transaction_workspace_screen.dart';

enum _TransactionView { all, active, actionRequired, history }

extension on _TransactionView {
  String get label => switch (this) {
    _TransactionView.all => 'All',
    _TransactionView.active => 'Active',
    _TransactionView.actionRequired => 'Your action',
    _TransactionView.history => 'History',
  };
}

class MyTransactionsScreen extends StatefulWidget {
  final ServiceTransactionParticipantRole? role;
  final String actorId;

  const MyTransactionsScreen({
    required this.actorId,
    this.role,
    super.key,
  });

  @override
  State<MyTransactionsScreen> createState() => _MyTransactionsScreenState();
}

class _MyTransactionsScreenState extends State<MyTransactionsScreen> {
  _TransactionView _view = _TransactionView.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(refreshHdcWorkflow(context));
    });
  }

  List<ServiceTransaction> _visibleTransactions(
    List<ServiceTransaction> transactions,
  ) {
    final filtered = transactions.where((transaction) {
      final role = widget.role ?? transaction.roleFor(widget.actorId);
      return switch (_view) {
        _TransactionView.all => true,
        _TransactionView.active => transaction.status.isActive,
        _TransactionView.actionRequired =>
          role != null && _requiresParticipantAction(transaction, role),
        _TransactionView.history => !transaction.status.isActive,
      };
    });

    return [...filtered]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  int _count(
    _TransactionView view,
    List<ServiceTransaction> transactions,
  ) {
    return transactions.where((transaction) {
      final role = widget.role ?? transaction.roleFor(widget.actorId);
      return switch (view) {
        _TransactionView.all => true,
        _TransactionView.active => transaction.status.isActive,
        _TransactionView.actionRequired =>
          role != null && _requiresParticipantAction(transaction, role),
        _TransactionView.history => !transaction.status.isActive,
      };
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServiceTransactionProvider>();
    final sync = context.watch<HdcWorkflowSyncProvider?>();
    final repositoryTransactions = switch (widget.role) {
      ServiceTransactionParticipantRole.customer =>
        provider.forCustomer(widget.actorId),
      ServiceTransactionParticipantRole.technician =>
        provider.forTechnician(widget.actorId),
      null => provider.forParticipant(widget.actorId),
    };
    final transactions = repositoryTransactions
        .where(
          (transaction) =>
              _participantRoleFor(
                transaction: transaction,
                actorId: widget.actorId,
                requestedRole: widget.role,
              ) !=
              null,
        )
        .toList(growable: false);
    final visibleTransactions = _visibleTransactions(transactions);
    final isRefreshing = provider.isLoading || (sync?.isSyncing ?? false);
    final loadError = provider.lastError ?? sync?.lastError;
    final activeCount = _count(_TransactionView.active, transactions);
    final actionCount = _count(
      _TransactionView.actionRequired,
      transactions,
    );
    final historyCount = _count(_TransactionView.history, transactions);

    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle(widget.role)),
        actions: [
          IconButton(
            tooltip: 'Refresh services',
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
            key: const Key('hdc-transaction-list'),
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
                        eyebrow: _heroEyebrow(widget.role),
                        title: _heroTitle(widget.role),
                        description: _heroDescription(widget.role),
                        icon: Icons.handyman_outlined,
                        tags: [
                          HDCFlowTag(
                            label: '${transactions.length} total',
                            icon: Icons.workspaces_outline,
                            color: HDCColors.accent,
                          ),
                          HDCFlowTag(
                            label: '$activeCount active',
                            icon: Icons.bolt_outlined,
                            color: HDCColors.signal,
                          ),
                          HDCFlowTag(
                            label: '$actionCount need your action',
                            icon: Icons.notification_important_outlined,
                            color: actionCount == 0
                                ? HDCColors.success
                                : HDCColors.warm,
                          ),
                        ],
                      ),
                      if (loadError != null && transactions.isNotEmpty) ...[
                        const SizedBox(height: HDCSpacing.md),
                        _TransactionSyncWarning(
                          onRetry: () => refreshHdcWorkflow(context),
                        ),
                      ],
                      const SizedBox(height: HDCSpacing.lg),
                      _TransactionFilters(
                        selected: _view,
                        transactions: transactions,
                        actorId: widget.actorId,
                        role: widget.role,
                        onSelected: (view) => setState(() => _view = view),
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                      if (isRefreshing && transactions.isEmpty)
                        const _TransactionLoading()
                      else if (loadError != null && transactions.isEmpty)
                        _TransactionLoadError(
                          onRetry: () => refreshHdcWorkflow(context),
                        )
                      else if (transactions.isEmpty)
                        _EmptyTransactions(role: widget.role)
                      else if (visibleTransactions.isEmpty)
                        _EmptyTransactionView(
                          view: _view,
                          historyCount: historyCount,
                          onShowAll: () => setState(
                            () => _view = _TransactionView.all,
                          ),
                        )
                      else
                        _TransactionGrid(
                          transactions: visibleTransactions,
                          requestedRole: widget.role,
                          actorId: widget.actorId,
                        ),
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

class _TransactionFilters extends StatelessWidget {
  final _TransactionView selected;
  final List<ServiceTransaction> transactions;
  final String actorId;
  final ServiceTransactionParticipantRole? role;
  final ValueChanged<_TransactionView> onSelected;

  const _TransactionFilters({
    required this.selected,
    required this.transactions,
    required this.actorId,
    required this.role,
    required this.onSelected,
  });

  int _count(_TransactionView view) {
    return transactions.where((transaction) {
      final participantRole = role ?? transaction.roleFor(actorId);
      return switch (view) {
        _TransactionView.all => true,
        _TransactionView.active => transaction.status.isActive,
        _TransactionView.actionRequired =>
          participantRole != null &&
              _requiresParticipantAction(transaction, participantRole),
        _TransactionView.history => !transaction.status.isActive,
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
          for (final view in _TransactionView.values)
            ChoiceChip(
              key: Key('hdc-transaction-filter-${view.name}'),
              selected: view == selected,
              onSelected: (_) => onSelected(view),
              label: Text('${view.label}  ${_count(view)}'),
            ),
        ],
      ),
    );
  }
}

class _TransactionGrid extends StatelessWidget {
  final List<ServiceTransaction> transactions;
  final ServiceTransactionParticipantRole? requestedRole;
  final String actorId;

  const _TransactionGrid({
    required this.transactions,
    required this.requestedRole,
    required this.actorId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960 ? 2 : 1;
        final width = columns == 2
            ? (constraints.maxWidth - HDCSpacing.md) / 2
            : constraints.maxWidth;

        return Wrap(
          key: const Key('hdc-transaction-results'),
          spacing: HDCSpacing.md,
          runSpacing: HDCSpacing.md,
          children: transactions.map((transaction) {
            final participantRole = _participantRoleFor(
              transaction: transaction,
              actorId: actorId,
              requestedRole: requestedRole,
            );
            if (participantRole == null) return const SizedBox.shrink();
            return SizedBox(
              width: width,
              child: _TransactionCard(
                transaction: transaction,
                role: participantRole,
                actorId: actorId,
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final ServiceTransaction transaction;
  final ServiceTransactionParticipantRole role;
  final String actorId;

  const _TransactionCard({
    required this.transaction,
    required this.role,
    required this.actorId,
  });

  void _open(BuildContext context) {
    Navigator.of(context).push(
      HDCPageRoute<void>(
        page: ServiceTransactionWorkspaceScreen(
          transactionId: transaction.id,
          actorId: actorId,
          role: role,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final counterpart = role == ServiceTransactionParticipantRole.customer
        ? transaction.technicianName
        : transaction.customerName;
    final requiresAction = _requiresParticipantAction(transaction, role);
    final statusColor = _statusColor(transaction.status);

    return HDCCard(
      key: Key('hdc-transaction-card-${transaction.id}'),
      onTap: () => _open(context),
      elevated: requiresAction,
      borderColor: requiresAction
          ? HDCColors.warning.withValues(alpha: 0.40)
          : HDCColors.border,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _statusIcon(transaction.status),
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: HDCSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.requestTitle,
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
                          '$counterpart • ${transaction.categoryName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HDCColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: HDCSpacing.xs),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: HDCColors.textSecondary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: HDCSpacing.md),
              Wrap(
                spacing: HDCSpacing.xs,
                runSpacing: HDCSpacing.xs,
                children: [
                  HDCStatusBadge(
                    label: transaction.status.label,
                    tone: _statusTone(transaction.status),
                    icon: _statusIcon(transaction.status),
                  ),
                  HDCStatusBadge(
                    label: 'As ${role.label}',
                    tone: HDCStatusTone.neutral,
                    icon: role == ServiceTransactionParticipantRole.customer
                        ? Icons.person_outline
                        : Icons.engineering_outlined,
                  ),
                  if (requiresAction)
                    const HDCStatusBadge(
                      label: 'Your action',
                      tone: HDCStatusTone.warning,
                      icon: Icons.notification_important_outlined,
                    ),
                ],
              ),
              const SizedBox(height: HDCSpacing.md),
              _TransactionMetaGrid(
                transaction: transaction,
                compact: compact,
              ),
              const SizedBox(height: HDCSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: HDCSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Updated ${_dateLabel(transaction.updatedAt)}',
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: HDCSpacing.xs),
                  const Text(
                    'Open Workspace',
                    style: TextStyle(
                      color: HDCColors.secondary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: HDCColors.secondary,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TransactionMetaGrid extends StatelessWidget {
  final ServiceTransaction transaction;
  final bool compact;

  const _TransactionMetaGrid({
    required this.transaction,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - HDCSpacing.sm) / 2;
        return Wrap(
          spacing: HDCSpacing.sm,
          runSpacing: HDCSpacing.xs,
          children: [
            SizedBox(
              width: width,
              child: _Meta(
                icon: Icons.receipt_long_outlined,
                label: transaction.id,
              ),
            ),
            SizedBox(
              width: width,
              child: _Meta(
                icon: Icons.payments_outlined,
                label:
                    'PHP ${transaction.acceptedTerms.totalEstimate.toStringAsFixed(0)}',
              ),
            ),
            SizedBox(
              width: constraints.maxWidth,
              child: _Meta(
                icon: Icons.location_on_outlined,
                label: transaction.serviceLocation,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Meta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: HDCColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  final ServiceTransactionParticipantRole? role;

  const _EmptyTransactions({required this.role});

  @override
  Widget build(BuildContext context) {
    return HDCEmptyState(
      icon: Icons.handshake_outlined,
      title: switch (role) {
        ServiceTransactionParticipantRole.customer =>
          'No accepted services yet',
        ServiceTransactionParticipantRole.technician =>
          'No technician jobs yet',
        null => 'No service workspaces yet',
      },
      description: switch (role) {
        ServiceTransactionParticipantRole.customer =>
          'A participant-protected workspace appears here after you accept '
              'a technician proposal.',
        ServiceTransactionParticipantRole.technician =>
          'Customer-accepted proposals appear here as tracked technician jobs.',
        null =>
          'Accepted services appear here whether you joined as the Customer '
              'or the Technician.',
      },
    );
  }
}

class _EmptyTransactionView extends StatelessWidget {
  final _TransactionView view;
  final int historyCount;
  final VoidCallback onShowAll;

  const _EmptyTransactionView({
    required this.view,
    required this.historyCount,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    return HDCEmptyState(
      icon: view == _TransactionView.actionRequired
          ? Icons.task_alt_outlined
          : Icons.filter_alt_off_outlined,
      title: view == _TransactionView.actionRequired
          ? 'Nothing needs your action'
          : 'No workspaces in this view',
      description: view == _TransactionView.actionRequired
          ? 'You are caught up. HDC still keeps every active and completed '
              'service record available in the All view.'
          : historyCount > 0
              ? 'Your other service records remain available. Show all '
                  'workspaces to review them.'
              : 'Your service records remain unchanged. Choose another view '
                  'to see the available workspaces.',
      color: view == _TransactionView.actionRequired
          ? HDCColors.success
          : HDCColors.secondary,
      actions: [
        OutlinedButton.icon(
          onPressed: onShowAll,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Show All Workspaces'),
        ),
      ],
    );
  }
}

class _TransactionLoading extends StatelessWidget {
  const _TransactionLoading();

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

class _TransactionLoadError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _TransactionLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return HDCEmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Service workspaces could not be loaded',
      description:
          'No service record was changed. Check the connection and try '
          'loading your workspaces again.',
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

class _TransactionSyncWarning extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _TransactionSyncWarning({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      color: HDCColors.warning.withValues(alpha: 0.07),
      borderColor: HDCColors.warning.withValues(alpha: 0.24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final message = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sync_problem, color: HDCColors.warning),
              const SizedBox(width: HDCSpacing.sm),
              const Expanded(
                child: Text(
                  'Some service updates may be delayed. The records shown '
                  'here were not changed.',
                  style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                message,
                const SizedBox(height: HDCSpacing.sm),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Retry Sync'),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: message),
              const SizedBox(width: HDCSpacing.md),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          );
        },
      ),
    );
  }
}

bool _requiresParticipantAction(
  ServiceTransaction transaction,
  ServiceTransactionParticipantRole role,
) {
  if (role == ServiceTransactionParticipantRole.customer) {
    return transaction.status ==
        ServiceTransactionStatus.awaitingCustomerConfirmation;
  }

  return switch (transaction.status) {
    ServiceTransactionStatus.confirmed ||
    ServiceTransactionStatus.scheduled ||
    ServiceTransactionStatus.technicianEnRoute ||
    ServiceTransactionStatus.arrived ||
    ServiceTransactionStatus.inProgress => true,
    ServiceTransactionStatus.created ||
    ServiceTransactionStatus.awaitingCustomerConfirmation ||
    ServiceTransactionStatus.completed ||
    ServiceTransactionStatus.cancelled ||
    ServiceTransactionStatus.disputed => false,
  };
}

ServiceTransactionParticipantRole? _participantRoleFor({
  required ServiceTransaction transaction,
  required String actorId,
  required ServiceTransactionParticipantRole? requestedRole,
}) {
  final participantRole = transaction.roleFor(actorId);
  if (participantRole == null ||
      (requestedRole != null && participantRole != requestedRole)) {
    return null;
  }
  return participantRole;
}

String _screenTitle(ServiceTransactionParticipantRole? role) => switch (role) {
  ServiceTransactionParticipantRole.customer => 'My Active Services',
  ServiceTransactionParticipantRole.technician => 'My Technician Jobs',
  null => 'My Service Workspaces',
};

String _heroEyebrow(ServiceTransactionParticipantRole? role) => switch (role) {
  ServiceTransactionParticipantRole.customer => 'Customer service center',
  ServiceTransactionParticipantRole.technician => 'Technician job center',
  null => 'Participant service center',
};

String _heroTitle(ServiceTransactionParticipantRole? role) => switch (role) {
  ServiceTransactionParticipantRole.customer =>
    'Your accepted services, from start to finish',
  ServiceTransactionParticipantRole.technician =>
    'Your technician jobs, organized by next step',
  null => 'Every service workspace connected to this account',
};

String _heroDescription(ServiceTransactionParticipantRole? role) =>
    switch (role) {
      ServiceTransactionParticipantRole.customer =>
        'Follow technician progress, review accepted terms, use '
            'participant-authorized tools, and confirm completion only when '
            'the service is ready.',
      ServiceTransactionParticipantRole.technician =>
        'Open each accepted job, follow the recorded service sequence, and '
            'send only authorized status updates to the Customer.',
      null =>
        'HDC keeps Customer and Technician workspaces separated by the '
            'account role recorded on each accepted transaction.',
    };

String _dateLabel(DateTime value) {
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
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

HDCStatusTone _statusTone(ServiceTransactionStatus status) => switch (status) {
  ServiceTransactionStatus.completed => HDCStatusTone.success,
  ServiceTransactionStatus.cancelled || ServiceTransactionStatus.disputed =>
    HDCStatusTone.danger,
  ServiceTransactionStatus.awaitingCustomerConfirmation =>
    HDCStatusTone.warning,
  ServiceTransactionStatus.technicianEnRoute ||
  ServiceTransactionStatus.inProgress => HDCStatusTone.info,
  ServiceTransactionStatus.created ||
  ServiceTransactionStatus.confirmed ||
  ServiceTransactionStatus.scheduled ||
  ServiceTransactionStatus.arrived => HDCStatusTone.neutral,
};

Color _statusColor(ServiceTransactionStatus status) => switch (status) {
  ServiceTransactionStatus.completed => HDCColors.success,
  ServiceTransactionStatus.cancelled || ServiceTransactionStatus.disputed =>
    HDCColors.danger,
  ServiceTransactionStatus.awaitingCustomerConfirmation => HDCColors.warning,
  ServiceTransactionStatus.technicianEnRoute ||
  ServiceTransactionStatus.inProgress => HDCColors.info,
  ServiceTransactionStatus.created ||
  ServiceTransactionStatus.confirmed ||
  ServiceTransactionStatus.scheduled ||
  ServiceTransactionStatus.arrived => HDCColors.secondary,
};

IconData _statusIcon(ServiceTransactionStatus status) => switch (status) {
  ServiceTransactionStatus.created => Icons.fiber_new_outlined,
  ServiceTransactionStatus.confirmed => Icons.handshake_outlined,
  ServiceTransactionStatus.scheduled => Icons.event_available_outlined,
  ServiceTransactionStatus.technicianEnRoute => Icons.directions_car_outlined,
  ServiceTransactionStatus.arrived => Icons.location_on_outlined,
  ServiceTransactionStatus.inProgress => Icons.build_outlined,
  ServiceTransactionStatus.awaitingCustomerConfirmation =>
    Icons.fact_check_outlined,
  ServiceTransactionStatus.completed => Icons.verified_outlined,
  ServiceTransactionStatus.cancelled => Icons.cancel_outlined,
  ServiceTransactionStatus.disputed => Icons.gavel_outlined,
};
