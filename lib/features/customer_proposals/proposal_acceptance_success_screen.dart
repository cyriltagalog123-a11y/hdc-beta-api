import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/proposal_acceptance_result.dart';
import '../../models/service_transaction.dart';
import '../dashboard/dashboard_screen.dart';
import '../transactions/service_transaction_workspace_screen.dart';

class ProposalAcceptanceSuccessScreen extends StatelessWidget {
  final ProposalAcceptanceResult result;
  final String transactionId;

  const ProposalAcceptanceSuccessScreen({
    required this.result,
    required this.transactionId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final proposal = result.acceptedProposal;

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Technician Selected'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: HDCColors.success.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 50,
                          color: HDCColors.success,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Proposal Accepted',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${proposal.reputation.technicianName} has been '
                        'selected and the service workspace is ready.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: HDCColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _InfoLine(
                        label: 'Accepted estimate',
                        value:
                            'PHP ${proposal.estimatedTotal.toStringAsFixed(0)}',
                      ),
                      _InfoLine(
                        label: 'Competing proposals closed',
                        value: '${result.competingProposalsClosed}',
                      ),
                      _InfoLine(
                        label: 'Transaction',
                        value: transactionId,
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: HDCColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'The accepted terms are now stored in the HDC '
                          'service transaction. Customer and technician '
                          'progress updates use this shared workspace.',
                          textAlign: TextAlign.center,
                          style: TextStyle(height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              HDCPageRoute<void>(
                                page: ServiceTransactionWorkspaceScreen(
                                  transactionId: transactionId,
                                  actorId: result.updatedRequest.customerId,
                                  role:
                                      ServiceTransactionParticipantRole.customer,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.work_outline),
                          label: const Text('Open Service Workspace'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                builder: (_) => const DashboardScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.dashboard_outlined),
                          label: const Text('Return to Dashboard'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
              style: const TextStyle(color: HDCColors.textSecondary),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
