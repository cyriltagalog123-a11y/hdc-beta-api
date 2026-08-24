import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/account_recovery_review.dart';
import '../../providers/hdc_internal_dashboard_provider.dart';

class AccountRecoveryReviewScreen extends StatefulWidget {
  const AccountRecoveryReviewScreen({super.key});

  @override
  State<AccountRecoveryReviewScreen> createState() =>
      _AccountRecoveryReviewScreenState();
}

class _AccountRecoveryReviewScreenState
    extends State<AccountRecoveryReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<HdcInternalDashboardProvider>().loadRecoveryReviewQueue(),
      );
    });
  }

  Future<void> _review(
    AccountRecoveryReviewRequest request, {
    required bool approve,
  }) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          approve ? 'Approve manual recovery?' : 'Reject manual recovery?',
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${request.displayName} · ${request.publicMemberId}'),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: approve
                      ? 'Private review note (optional)'
                      : 'Private rejection note (required)',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (approve)
                const Text(
                  'Approval creates a 15-minute one-use code. It does not '
                  'change or reveal the member password.',
                  style: TextStyle(
                    color: HDCColors.textSecondary,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: approve ? HDCColors.success : HDCColors.danger,
            ),
            onPressed: () {
              if (!approve && noteController.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: Text(approve ? 'Approve and Create Code' : 'Reject'),
          ),
        ],
      ),
    );
    final note = noteController.text;
    noteController.dispose();
    if (confirmed != true || !mounted) return;

    try {
      final result = await context
          .read<HdcInternalDashboardProvider>()
          .reviewRecoveryRequest(
            request,
            approve: approve,
            note: note,
          );
      if (!mounted) return;
      if (approve) {
        await _showOneTimeCode(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recovery request rejected.')),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _showOneTimeCode(AccountRecoveryReviewResult result) async {
    final token = result.manualResetToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('HDC did not return the approved one-time code.'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('One-time reset code'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy this code now and deliver it to the member only after '
                'identity confirmation. HDC will not display it again.',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HDCColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  token,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                result.expiresAt == null
                    ? 'The code is short-lived and can be used once.'
                    : 'Expires ${_dateTimeLabel(result.expiresAt!)} and can be used once.',
                style: const TextStyle(color: HDCColors.danger),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('One-time code copied.')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Code'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('I Saved the Code'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<HdcInternalDashboardProvider>();
    final requests = workspace.recoveryReviewQueue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Account Recovery'),
        actions: [
          IconButton(
            tooltip: 'Refresh recovery queue',
            onPressed: workspace.isLoading
                ? null
                : workspace.loadRecoveryReviewQueue,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: workspace.loadRecoveryReviewQueue,
        child: requests.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.security_outlined,
                    size: 72,
                    color: HDCColors.success,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    workspace.isLoading
                        ? 'Loading recovery queue…'
                        : 'No pending recovery reviews',
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
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return _RecoveryReviewCard(
                    request: request,
                    busy: workspace.isSubmitting,
                    onApprove: () => _review(request, approve: true),
                    onReject: () => _review(request, approve: false),
                  );
                },
              ),
      ),
    );
  }
}

class _RecoveryReviewCard extends StatelessWidget {
  final AccountRecoveryReviewRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RecoveryReviewCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_search_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        '${request.publicMemberId} · ${request.email}',
                        style: const TextStyle(
                          color: HDCColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Chip(label: Text('Private')),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'The automatic recovery check did not issue a code. Confirm the '
              'member identity using trusted information outside the recovery '
              'answers before approving.',
              style: TextStyle(height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(
              'Requested ${_dateTimeLabel(request.createdAt)} · Delivery ${request.deliveryStatus}',
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
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.block),
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

String _dateTimeLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
