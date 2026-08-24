import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../models/proposal.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/proposal_acceptance_provider.dart';
import '../../providers/service_transaction_provider.dart';
import 'proposal_acceptance_success_screen.dart';

Future<void> startProposalAcceptanceFlow(
  BuildContext context, {
  required Proposal proposal,
}) async {
  final identity = context.read<HDCAuthProvider>().identity;
  if (identity == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sign in to accept a technician proposal.'),
      ),
    );
    return;
  }
  if (!proposal.status.isActive) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This proposal is no longer available for acceptance.'),
      ),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Accept this proposal?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              proposal.reputation.technicianName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _SummaryLine(
              label: 'Total estimate',
              value: 'PHP ${proposal.estimatedTotal.toStringAsFixed(0)}',
            ),
            _SummaryLine(
              label: 'Warranty',
              value: proposal.warrantyDays == 0
                  ? 'None'
                  : '${proposal.warrantyDays} days',
            ),
            _SummaryLine(
              label: 'Proposal quality',
              value: '${proposal.qualityScore}%',
            ),
            const SizedBox(height: 14),
            const Text(
              'Accepting this proposal selects this technician, closes '
              'competing active proposals, stops new offers, and creates '
              'the service transaction workspace.',
              style: TextStyle(height: 1.45),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep Reviewing'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Accept Proposal'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final result =
        await context.read<ProposalAcceptanceProvider>().acceptProposal(
              proposalId: proposal.id,
              actingCustomerId: identity.id,
            );

    if (!context.mounted) return;

    final transaction = await context
        .read<ServiceTransactionProvider>()
        .ensureForSeed(result.transactionSeed.id);

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      HDCPageRoute<void>(
        page: ProposalAcceptanceSuccessScreen(
          result: result,
          transactionId: transaction.id,
        ),
      ),
      (route) => route.isFirst,
    );
  } on Object catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not accept proposal: $error'),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
