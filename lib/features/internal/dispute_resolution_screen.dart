import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/transaction_toolbox.dart';
import '../../providers/hdc_internal_dashboard_provider.dart';

class DisputeResolutionScreen extends StatelessWidget {
  const DisputeResolutionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HdcInternalDashboardProvider>();
    final disputes = provider.disputeQueue
        .where((item) => item.isActive)
        .toList(growable: false);
    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Dispute Resolution'),
        actions: [
          IconButton(
            tooltip: 'Refresh disputes',
            onPressed: provider.isLoading ? null : provider.loadDisputeQueue,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: provider.isLoading && disputes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : disputes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text('The active dispute queue is clear.'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: provider.loadDisputeQueue,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: disputes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) => _DisputeCard(
                      dispute: disputes[index],
                      events: provider.disputeEvents
                          .where((event) => event.disputeId == disputes[index].id)
                          .toList(growable: false),
                      saving: provider.isSubmitting,
                      onResolve: () => _resolve(context, disputes[index]),
                    ),
                  ),
                ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    HdcServiceDispute dispute,
  ) async {
    final decision = await showDialog<_ResolutionInput>(
      context: context,
      builder: (_) => const _ResolutionDialog(),
    );
    if (decision == null || !context.mounted) return;
    try {
      await context.read<HdcInternalDashboardProvider>().resolveDispute(
            dispute,
            outcome: decision.outcome,
            note: decision.note,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispute resolution recorded.')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _DisputeCard extends StatelessWidget {
  final HdcServiceDispute dispute;
  final List<HdcDisputeEvent> events;
  final bool saving;
  final VoidCallback onResolve;

  const _DisputeCard({
    required this.dispute,
    required this.events,
    required this.saving,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  dispute.requestTitle ?? dispute.transactionId,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Chip(label: Text(_label(dispute.status))),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${dispute.customerName ?? 'Customer'} ↔ '
              '${dispute.technicianName ?? 'Technician'}',
              style: const TextStyle(color: HDCColors.textSecondary),
            ),
            const Divider(height: 26),
            Text(
              _label(dispute.reasonCode),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(dispute.summary, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 8),
            Text(
              'Requested outcome: ${_label(dispute.requestedOutcome)} • '
              'Previous service state: ${_label(dispute.priorTransactionStatus)}',
              style: const TextStyle(color: HDCColors.textSecondary),
            ),
            if (events.isNotEmpty) ...[
              const SizedBox(height: 14),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Case history (${events.length})'),
                children: [
                  for (final event in events)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(_label(event.eventType)),
                      subtitle: Text(event.message),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: saving ? null : onResolve,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Resolve case'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolutionInput {
  final String outcome;
  final String note;
  const _ResolutionInput(this.outcome, this.note);
}

class _ResolutionDialog extends StatefulWidget {
  const _ResolutionDialog();

  @override
  State<_ResolutionDialog> createState() => _ResolutionDialogState();
}

class _ResolutionDialogState extends State<_ResolutionDialog> {
  String outcome = 'serviceContinues';
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const outcomes = [
      'serviceContinues',
      'serviceCompleted',
      'serviceCancelled',
      'partialRefund',
      'fullRefund',
      'noAdjustment',
      'other',
    ];
    return AlertDialog(
      title: const Text('Record final resolution'),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: outcome,
              items: outcomes
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(_label(value)),
                      ))
                  .toList(growable: false),
              onChanged: (value) => setState(() => outcome = value ?? outcome),
              decoration: const InputDecoration(labelText: 'Outcome'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              minLines: 4,
              maxLines: 9,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Resolution note (minimum 10 characters)',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Refund outcomes record the decision and cancel the service. '
              'The actual external refund must still be recorded and '
              'confirmed in the participant payment ledger.',
              style: TextStyle(color: HDCColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final text = note.text.trim();
            if (text.length < 10) return;
            Navigator.pop(context, _ResolutionInput(outcome, text));
          },
          child: const Text('Resolve dispute'),
        ),
      ],
    );
  }
}

String _label(String value) {
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return spaced.isEmpty
      ? spaced
      : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
