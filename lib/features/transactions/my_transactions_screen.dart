import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/workflow/hdc_workflow_refresh.dart';
import '../../models/service_transaction.dart';
import '../../providers/hdc_workflow_sync_provider.dart';
import '../../providers/service_transaction_provider.dart';
import 'service_transaction_workspace_screen.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(refreshHdcWorkflow(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServiceTransactionProvider>();
    final sync = context.watch<HdcWorkflowSyncProvider?>();
    final transactions = switch (widget.role) {
      ServiceTransactionParticipantRole.customer =>
        provider.forCustomer(widget.actorId),
      ServiceTransactionParticipantRole.technician =>
        provider.forTechnician(widget.actorId),
      null => provider.forParticipant(widget.actorId),
    };
    final isRefreshing = provider.isLoading || (sync?.isSyncing ?? false);
    final loadError = provider.lastError ?? sync?.lastError;

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: Text(switch (widget.role) {
          ServiceTransactionParticipantRole.customer => 'My Active Services',
          ServiceTransactionParticipantRole.technician =>
            'My Technician Jobs',
          null => 'My Service Workspaces',
        }),
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
      body: isRefreshing && transactions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : loadError != null && transactions.isEmpty
              ? _LoadError(
                  onRetry: () => refreshHdcWorkflow(context),
                )
              : transactions.isEmpty
                  ? _EmptyTransactions(role: widget.role)
                  : RefreshIndicator(
                      onRefresh: () => refreshHdcWorkflow(context),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        itemCount: transactions.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final transaction = transactions[index];
                          final participantRole = widget.role ??
                              transaction.roleFor(widget.actorId);
                          if (participantRole == null) {
                            return const SizedBox.shrink();
                          }
                          return _TransactionCard(
                            transaction: transaction,
                            role: participantRole,
                            actorId: widget.actorId,
                          );
                        },
                      ),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final counterpart = role == ServiceTransactionParticipantRole.customer
        ? transaction.technicianName
        : transaction.customerName;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            HDCPageRoute<void>(
              page: ServiceTransactionWorkspaceScreen(
                transactionId: transaction.id,
                actorId: actorId,
                role: role,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _statusColor(transaction.status)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.handshake_outlined,
                  color: _statusColor(transaction.status),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.requestTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusChip(status: transaction.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$counterpart • ${transaction.categoryName}',
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        _Meta(
                          icon: Icons.receipt_long_outlined,
                          label: transaction.id,
                        ),
                        _Meta(
                          icon: Icons.badge_outlined,
                          label: 'As ${role.label}',
                        ),
                        _Meta(
                          icon: Icons.payments_outlined,
                          label:
                              'PHP ${transaction.acceptedTerms.totalEstimate.toStringAsFixed(0)}',
                        ),
                        _Meta(
                          icon: Icons.location_on_outlined,
                          label: transaction.serviceLocation,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ServiceTransactionStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Meta({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: HDCColors.textSecondary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: HDCColors.textSecondary,
            fontSize: 12,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.handshake_outlined,
                size: 64,
                color: HDCColors.textSecondary,
              ),
              const SizedBox(height: 18),
              Text(
                switch (role) {
                  ServiceTransactionParticipantRole.customer =>
                    'No active services yet',
                  ServiceTransactionParticipantRole.technician =>
                    'No technician jobs yet',
                  null => 'No service workspaces yet',
                },
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                switch (role) {
                  ServiceTransactionParticipantRole.customer =>
                    'A service workspace appears here after you accept a '
                        'technician proposal.',
                  ServiceTransactionParticipantRole.technician =>
                    'Accepted customer proposals appear here as technician '
                        'jobs.',
                  null =>
                    'Accepted services appear here whether you joined as the '
                        'customer or the technician.',
                },
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: HDCColors.danger,
            ),
            const SizedBox(height: 16),
            const Text(
              'Services could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(ServiceTransactionStatus status) {
  switch (status) {
    case ServiceTransactionStatus.completed:
      return HDCColors.success;
    case ServiceTransactionStatus.cancelled:
    case ServiceTransactionStatus.disputed:
      return HDCColors.danger;
    case ServiceTransactionStatus.awaitingCustomerConfirmation:
      return HDCColors.warning;
    case ServiceTransactionStatus.inProgress:
    case ServiceTransactionStatus.technicianEnRoute:
      return HDCColors.info;
    case ServiceTransactionStatus.created:
    case ServiceTransactionStatus.confirmed:
    case ServiceTransactionStatus.scheduled:
    case ServiceTransactionStatus.arrived:
      return HDCColors.secondary;
  }
}
