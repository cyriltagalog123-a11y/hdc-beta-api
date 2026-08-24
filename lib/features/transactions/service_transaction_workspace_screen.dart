import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/service_transaction.dart';
import '../../providers/service_transaction_provider.dart';
import '../messaging/private_transaction_chat_screen.dart';

class ServiceTransactionWorkspaceScreen extends StatelessWidget {
  final String transactionId;
  final String actorId;
  final ServiceTransactionParticipantRole role;

  const ServiceTransactionWorkspaceScreen({
    required this.transactionId,
    required this.actorId,
    required this.role,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServiceTransactionProvider>();
    final transaction = provider.byId(transactionId);

    if (transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service Workspace')),
        body: const Center(
          child: Text('This service transaction was not found.'),
        ),
      );
    }

    final action = _nextAction(
      transaction: transaction,
      role: role,
    );

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Service Workspace'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WorkspaceHeader(
                    transaction: transaction,
                    role: role,
                  ),
                  const SizedBox(height: 18),
                  _NexusWorkspaceInsight(
                    transaction: transaction,
                    role: role,
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 860;

                      final terms = _AcceptedTermsCard(
                        transaction: transaction,
                      );
                      final participants = _ParticipantsCard(
                        transaction: transaction,
                        role: role,
                      );

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: terms),
                            const SizedBox(width: 18),
                            Expanded(flex: 2, child: participants),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          terms,
                          const SizedBox(height: 18),
                          participants,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _TransactionTimeline(transaction: transaction),
                  const SizedBox(height: 18),
                  _FutureWorkspaceTools(
                    transaction: transaction,
                    actorId: actorId,
                  ),
                  const SizedBox(height: 18),
                  if (action != null)
                    _NextActionCard(
                      action: action,
                      isSaving: provider.isSaving,
                      onPressed: () => _performAction(
                        context,
                        provider,
                        transaction,
                        action,
                      ),
                    ),
                  if (action == null)
                    _NoActionCard(
                      transaction: transaction,
                      role: role,
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performAction(
    BuildContext context,
    ServiceTransactionProvider provider,
    ServiceTransaction transaction,
    _WorkspaceAction action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action.confirmationTitle),
        content: Text(action.confirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not Yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action.buttonLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await provider.transition(
        transactionId: transaction.id,
        toStatus: action.toStatus,
        actorId: actorId,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transaction updated to ${action.toStatus.label}.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update transaction: $error'),
        ),
      );
    }
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final ServiceTransaction transaction;
  final ServiceTransactionParticipantRole role;

  const _WorkspaceHeader({
    required this.transaction,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(transaction.status);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  transaction.requestTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    transaction.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${transaction.categoryName} • ${role.label} view',
              style: const TextStyle(
                color: HDCColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _HeaderMeta(
                  icon: Icons.receipt_long_outlined,
                  label: transaction.id,
                ),
                _HeaderMeta(
                  icon: Icons.location_on_outlined,
                  label: transaction.serviceLocation,
                ),
                _HeaderMeta(
                  icon: Icons.payments_outlined,
                  label:
                      'PHP ${transaction.acceptedTerms.totalEstimate.toStringAsFixed(0)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderMeta({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: HDCColors.textSecondary),
        const SizedBox(width: 6),
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

class _NexusWorkspaceInsight extends StatelessWidget {
  final ServiceTransaction transaction;
  final ServiceTransactionParticipantRole role;

  const _NexusWorkspaceInsight({
    required this.transaction,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HDCColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HDCColors.secondary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.smart_toy_outlined,
            color: HDCColors.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nexus: ${_nexusMessage(transaction, role)}',
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  String _nexusMessage(
    ServiceTransaction transaction,
    ServiceTransactionParticipantRole role,
  ) {
    switch (transaction.status) {
      case ServiceTransactionStatus.confirmed:
        return role == ServiceTransactionParticipantRole.technician
            ? 'The customer selected your proposal. Confirm the service schedule when you are ready.'
            : 'Your technician has been selected. The next step is technician schedule confirmation.';
      case ServiceTransactionStatus.scheduled:
        return role == ServiceTransactionParticipantRole.technician
            ? 'The service is scheduled. Update the workspace when you begin travelling to the customer.'
            : 'The service schedule is confirmed. HDC will show the technician travel status here.';
      case ServiceTransactionStatus.technicianEnRoute:
        return 'The technician is currently on the way to the service location.';
      case ServiceTransactionStatus.arrived:
        return role == ServiceTransactionParticipantRole.technician
            ? 'Arrival is recorded. Start the service only when you are ready to work on the technology issue.'
            : 'The technician has arrived. The workspace will update again when service begins.';
      case ServiceTransactionStatus.inProgress:
        return role == ServiceTransactionParticipantRole.technician
            ? 'The service is in progress. When work is ready for customer review, submit it for confirmation.'
            : 'The technician marked the service as in progress. Wait for the completion-review step.';
      case ServiceTransactionStatus.awaitingCustomerConfirmation:
        return role == ServiceTransactionParticipantRole.customer
            ? 'The technician says the work is ready. Review the result before confirming completion.'
            : 'The customer now controls final completion confirmation.';
      case ServiceTransactionStatus.completed:
        return 'This service transaction is complete. Receipt and warranty workflows will build on this record.';
      case ServiceTransactionStatus.cancelled:
        return 'This transaction was cancelled.';
      case ServiceTransactionStatus.disputed:
        return 'This transaction is under dispute. Future dispute tools will use this same transaction record.';
      case ServiceTransactionStatus.created:
        return 'The transaction has been created and is awaiting confirmation.';
    }
  }
}

class _AcceptedTermsCard extends StatelessWidget {
  final ServiceTransaction transaction;

  const _AcceptedTermsCard({
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final terms = transaction.acceptedTerms;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accepted Service Terms',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 16),
            _InfoLine(
              label: 'Service fee',
              value: 'PHP ${terms.serviceFee.toStringAsFixed(0)}',
            ),
            _InfoLine(
              label: 'Estimated parts',
              value: terms.estimatedPartsCost == null
                  ? 'None listed'
                  : 'PHP ${terms.estimatedPartsCost!.toStringAsFixed(0)}',
            ),
            _InfoLine(
              label: 'Accepted estimate',
              value: 'PHP ${terms.totalEstimate.toStringAsFixed(0)}',
            ),
            _InfoLine(
              label: 'Earliest arrival',
              value: _dateTime(terms.earliestArrival),
            ),
            _InfoLine(
              label: 'Estimated duration',
              value: _duration(terms.estimatedDurationMinutes),
            ),
            _InfoLine(
              label: 'Warranty',
              value: terms.warrantyDays == 0
                  ? 'No warranty'
                  : '${terms.warrantyDays} days',
            ),
            const Divider(height: 30),
            _TextSection(
              title: 'Initial diagnosis',
              value: terms.diagnosis,
            ),
            _TextSection(
              title: 'Repair approach',
              value: terms.repairApproach,
            ),
            _TextSection(
              title: 'Professional notes',
              value: terms.professionalNotes,
            ),
          ],
        ),
      ),
    );
  }

  String _dateTime(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
            ? value.hour - 12
            : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '${value.month}/${value.day}/${value.year} • '
        '$hour:$minute $period';
  }

  String _duration(int minutes) {
    if (minutes < 60) return '$minutes min';

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (remaining == 0) {
      return '$hours ${hours == 1 ? 'hr' : 'hrs'}';
    }
    return '$hours hr $remaining min';
  }
}

class _ParticipantsCard extends StatelessWidget {
  final ServiceTransaction transaction;
  final ServiceTransactionParticipantRole role;

  const _ParticipantsCard({
    required this.transaction,
    required this.role,
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
              'Participants',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 16),
            _ParticipantTile(
              icon: Icons.person_outline,
              role: 'Customer',
              name: transaction.customerName,
              isYou: role == ServiceTransactionParticipantRole.customer,
            ),
            const SizedBox(height: 12),
            _ParticipantTile(
              icon: Icons.engineering_outlined,
              role: 'Technician',
              name: transaction.technicianName,
              isYou: role == ServiceTransactionParticipantRole.technician,
            ),
            const SizedBox(height: 18),
            const Text(
              'Exact service details in this workspace are intended only for authorized transaction participants.',
              style: TextStyle(
                color: HDCColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final IconData icon;
  final String role;
  final String name;
  final bool isYou;

  const _ParticipantTile({
    required this.icon,
    required this.role,
    required this.name,
    required this.isYou,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HDCColors.background,
        borderRadius: BorderRadius.circular(14),
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
                  role,
                  style: const TextStyle(
                    color: HDCColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (isYou)
            const Chip(
              label: Text('You'),
            ),
        ],
      ),
    );
  }
}

class _TransactionTimeline extends StatelessWidget {
  final ServiceTransaction transaction;

  const _TransactionTimeline({
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final activity = [...transaction.activity]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction Timeline',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < activity.length; index++)
              _TimelineEntry(
                entry: activity[index],
                showLine: index != activity.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final ServiceTransactionActivity entry;
  final bool showLine;

  const _TimelineEntry({
    required this.entry,
    required this.showLine,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: HDCColors.secondary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 17,
                    color: HDCColors.secondary,
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: HDCColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.message,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _time(entry.createdAt),
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

  String _time(DateTime value) {
    return '${value.month}/${value.day}/${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}


class _FutureWorkspaceTools extends StatelessWidget {
  final ServiceTransaction transaction;
  final String actorId;

  const _FutureWorkspaceTools({
    required this.transaction,
    required this.actorId,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _FutureTool(
        icon: Icons.chat_bubble_outline,
        title: 'Private Transaction Chat',
        subtitle: transaction.allowsPrivateMessaging
            ? 'Secure 1-to-1 transaction conversation for the customer and technician.'
            : 'Messaging unavailable for this transaction.',
        enabled: transaction.allowsPrivateMessaging,
        onTap: transaction.allowsPrivateMessaging
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PrivateTransactionChatScreen(
                      transactionId: transaction.id,
                      actorId: actorId,
                    ),
                  ),
                );
              }
            : null,
      ),
      const _FutureTool(
        icon: Icons.payments_outlined,
        title: 'Payment & Receipt',
        subtitle: 'Reserved for the payment and receipt workflow.',
      ),
      const _FutureTool(
        icon: Icons.folder_outlined,
        title: 'Documents',
        subtitle: 'Future reports, attachments, receipts, and warranty records.',
      ),
      const _FutureTool(
        icon: Icons.gavel_outlined,
        title: 'Dispute',
        subtitle: 'Dispute controls remain reserved for the dedicated workflow.',
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workspace Tools',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Private transaction chat is now active. Other transaction '
              'tools remain reserved for their dedicated workflows.',
              style: TextStyle(
                color: HDCColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 720
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width: width,
                          child: _FutureToolTile(item: item),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FutureTool {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const _FutureTool({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = false,
    this.onTap,
  });
}

class _FutureToolTile extends StatelessWidget {
  final _FutureTool item;

  const _FutureToolTile({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        item.enabled ? HDCColors.secondary : HDCColors.textSecondary;

    return Material(
      color: HDCColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.enabled ? item.onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.enabled
                  ? HDCColors.secondary.withValues(alpha: 0.22)
                  : HDCColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (item.enabled)
                          const Chip(
                            label: Text('Active'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.enabled)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.chevron_right,
                    color: HDCColors.secondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  final _WorkspaceAction action;
  final bool isSaving;
  final VoidCallback onPressed;

  const _NextActionCard({
    required this.action,
    required this.isSaving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Next Action',
                    style: TextStyle(
                      fontSize: 12,
                      color: HDCColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    action.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    action.description,
                    style: const TextStyle(
                      color: HDCColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            FilledButton.icon(
              onPressed: isSaving ? null : onPressed,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(action.icon),
              label: Text(action.buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoActionCard extends StatelessWidget {
  final ServiceTransaction transaction;
  final ServiceTransactionParticipantRole role;

  const _NoActionCard({
    required this.transaction,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final message = transaction.status.isTerminal
        ? 'No further service-status action is available.'
        : transaction.status == ServiceTransactionStatus.disputed
            ? 'Transaction status is frozen while the dispute is unresolved.'
            : 'The next status action belongs to the other transaction participant.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HDCColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HDCColors.border),
      ),
      child: Text(
        '${role.label}: $message',
        style: const TextStyle(
          color: HDCColors.textSecondary,
          height: 1.45,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: HDCColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  final String title;
  final String value;

  const _TextSection({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value.trim().isEmpty ? 'Not provided' : value,
            style: const TextStyle(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceAction {
  final String title;
  final String description;
  final String buttonLabel;
  final String confirmationTitle;
  final String confirmationMessage;
  final IconData icon;
  final ServiceTransactionStatus toStatus;

  const _WorkspaceAction({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.confirmationTitle,
    required this.confirmationMessage,
    required this.icon,
    required this.toStatus,
  });
}

_WorkspaceAction? _nextAction({
  required ServiceTransaction transaction,
  required ServiceTransactionParticipantRole role,
}) {
  if (role == ServiceTransactionParticipantRole.technician) {
    switch (transaction.status) {
      case ServiceTransactionStatus.confirmed:
        return const _WorkspaceAction(
          title: 'Confirm Service Schedule',
          description: 'Confirm the accepted schedule and prepare the service visit.',
          buttonLabel: 'Confirm Schedule',
          confirmationTitle: 'Confirm service schedule?',
          confirmationMessage:
              'This records that the technician has confirmed the service schedule.',
          icon: Icons.event_available_outlined,
          toStatus: ServiceTransactionStatus.scheduled,
        );
      case ServiceTransactionStatus.scheduled:
        return const _WorkspaceAction(
          title: 'Start Travel',
          description: 'Update the customer when you begin travelling to the service location.',
          buttonLabel: 'I\'m On The Way',
          confirmationTitle: 'Mark technician en route?',
          confirmationMessage:
              'The customer will see that the technician is travelling to the service location.',
          icon: Icons.directions_car_outlined,
          toStatus: ServiceTransactionStatus.technicianEnRoute,
        );
      case ServiceTransactionStatus.technicianEnRoute:
        return const _WorkspaceAction(
          title: 'Confirm Arrival',
          description: 'Record arrival at the service location.',
          buttonLabel: 'I Have Arrived',
          confirmationTitle: 'Confirm arrival?',
          confirmationMessage:
              'This records that the technician has reached the service location.',
          icon: Icons.location_on_outlined,
          toStatus: ServiceTransactionStatus.arrived,
        );
      case ServiceTransactionStatus.arrived:
        return const _WorkspaceAction(
          title: 'Start Service',
          description: 'Begin work on the technology issue after confirming it is safe to proceed.',
          buttonLabel: 'Start Service',
          confirmationTitle: 'Start service work?',
          confirmationMessage:
              'This marks the technology service as actively in progress.',
          icon: Icons.build_outlined,
          toStatus: ServiceTransactionStatus.inProgress,
        );
      case ServiceTransactionStatus.inProgress:
        return const _WorkspaceAction(
          title: 'Submit for Customer Review',
          description: 'Use this only when the work is ready for the customer to review.',
          buttonLabel: 'Ready for Review',
          confirmationTitle: 'Submit work for customer review?',
          confirmationMessage:
              'The customer will control the final completion confirmation after this step.',
          icon: Icons.fact_check_outlined,
          toStatus: ServiceTransactionStatus.awaitingCustomerConfirmation,
        );
      case ServiceTransactionStatus.created:
      case ServiceTransactionStatus.awaitingCustomerConfirmation:
      case ServiceTransactionStatus.completed:
      case ServiceTransactionStatus.cancelled:
      case ServiceTransactionStatus.disputed:
        return null;
    }
  }

  if (role == ServiceTransactionParticipantRole.customer &&
      transaction.status ==
          ServiceTransactionStatus.awaitingCustomerConfirmation) {
    return const _WorkspaceAction(
      title: 'Confirm Service Completion',
      description:
          'Confirm only after you have reviewed the completed technology service.',
      buttonLabel: 'Confirm Completion',
      confirmationTitle: 'Confirm service completion?',
      confirmationMessage:
          'This marks the transaction completed. Receipt and warranty records will use this completion state.',
      icon: Icons.verified_outlined,
      toStatus: ServiceTransactionStatus.completed,
    );
  }

  return null;
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
    case ServiceTransactionStatus.technicianEnRoute:
    case ServiceTransactionStatus.inProgress:
      return HDCColors.info;
    case ServiceTransactionStatus.created:
    case ServiceTransactionStatus.confirmed:
    case ServiceTransactionStatus.scheduled:
    case ServiceTransactionStatus.arrived:
      return HDCColors.secondary;
  }
}
