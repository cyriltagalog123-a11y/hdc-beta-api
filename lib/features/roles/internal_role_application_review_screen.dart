import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/platform_role_application.dart';
import '../../models/platform_role_application_form.dart';
import '../../providers/hdc_internal_dashboard_provider.dart';

class InternalRoleApplicationReviewScreen extends StatelessWidget {
  const InternalRoleApplicationReviewScreen({super.key});

  Future<void> _review(
    BuildContext context,
    PlatformRoleApplication application, {
    required _RoleReviewDecision decision,
  }) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${decision.dialogVerb} ${application.role.label}?',
        ),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: noteController,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: decision == _RoleReviewDecision.approved
                  ? 'Approval note (optional)'
                  : 'Review note (required)',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (decision != _RoleReviewDecision.approved &&
                  noteController.text.trim().isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: decision == _RoleReviewDecision.approved
                  ? HDCColors.success
                  : decision == _RoleReviewDecision.rejected
                      ? HDCColors.danger
                      : HDCColors.warning,
            ),
            child: Text(decision.actionLabel),
          ),
        ],
      ),
    );
    final note = noteController.text;
    noteController.dispose();
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<HdcInternalDashboardProvider>().reviewApplication(
            application,
            decision: decision.code,
            note: note,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${application.role.label} application ${decision.resultLabel}.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<HdcInternalDashboardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Role Approvals'),
        actions: [
          IconButton(
            tooltip: 'Refresh queue',
            onPressed: workspace.isLoading ? null : workspace.loadReviewQueue,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: workspace.loadReviewQueue,
        child: workspace.reviewQueue.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.task_alt,
                    size: 72,
                    color: HDCColors.success,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    workspace.isLoading
                        ? 'Loading approval queue…'
                        : 'No pending role applications',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (workspace.lastError != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${workspace.lastError}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: HDCColors.danger),
                    ),
                  ],
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: workspace.reviewQueue.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final application = workspace.reviewQueue[index];
                  return _ApplicationReviewCard(
                    application: application,
                    busy: workspace.isSubmitting,
                    onApprove: () => _review(
                      context,
                      application,
                      decision: _RoleReviewDecision.approved,
                    ),
                    onRequestChanges: () => _review(
                      context,
                      application,
                      decision: _RoleReviewDecision.changesRequested,
                    ),
                    onReject: () => _review(
                      context,
                      application,
                      decision: _RoleReviewDecision.rejected,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ApplicationReviewCard extends StatelessWidget {
  final PlatformRoleApplication application;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onRequestChanges;
  final VoidCallback onReject;

  const _ApplicationReviewCard({
    required this.application,
    required this.busy,
    required this.onApprove,
    required this.onRequestChanges,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final applicant = application.displayName ?? application.userId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        applicant,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (application.email != null)
                        Text(
                          application.email!,
                          style: const TextStyle(
                            color: HDCColors.textSecondary,
                          ),
                        ),
                      if (application.publicMemberId != null)
                        Text(
                          application.publicMemberId!,
                          style: const TextStyle(
                            color: HDCColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Chip(label: Text(application.role.label)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 7),
                Text(
                  'Private submitted answers · Form v${application.formVersion}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (application.answers.isEmpty)
              const Text('No structured answers were included.')
            else
              ...application.answers.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platformRoleApplicationAnswerLabel(
                          application.role,
                          entry.key,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: HDCColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(_answerValue(entry.value)),
                    ],
                  ),
                ),
              ),
            const Divider(height: 28),
            Text(
              'Additional note',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HDCColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              application.applicantNote.isEmpty
                  ? 'No application note was provided.'
                  : application.applicantNote,
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(
              'Submitted ${_dateLabel(application.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HDCColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onRequestChanges,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Request Changes'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _RoleReviewDecision {
  approved,
  changesRequested,
  rejected,
}

extension on _RoleReviewDecision {
  String get code => switch (this) {
        _RoleReviewDecision.approved => 'approved',
        _RoleReviewDecision.changesRequested => 'changes_requested',
        _RoleReviewDecision.rejected => 'rejected',
      };

  String get dialogVerb => switch (this) {
        _RoleReviewDecision.approved => 'Approve',
        _RoleReviewDecision.changesRequested => 'Request changes for',
        _RoleReviewDecision.rejected => 'Reject',
      };

  String get actionLabel => switch (this) {
        _RoleReviewDecision.approved => 'Approve Role',
        _RoleReviewDecision.changesRequested => 'Request Changes',
        _RoleReviewDecision.rejected => 'Reject Application',
      };

  String get resultLabel => switch (this) {
        _RoleReviewDecision.approved => 'approved',
        _RoleReviewDecision.changesRequested => 'returned for changes',
        _RoleReviewDecision.rejected => 'rejected',
      };
}

String _answerValue(Object? value) {
  if (value == true) return 'Confirmed';
  if (value == false) return 'Not confirmed';
  final text = '$value'.trim();
  return text.isEmpty ? 'Not provided' : text;
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
