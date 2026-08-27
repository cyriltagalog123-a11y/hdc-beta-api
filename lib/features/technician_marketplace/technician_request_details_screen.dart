import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/proposal.dart';
import '../../models/service_request.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/proposal_provider.dart';
import '../../providers/technician_marketplace_provider.dart';
import 'proposal_studio_screen.dart';

class TechnicianRequestDetailsScreen extends StatelessWidget {
  final ServiceRequest request;

  const TechnicianRequestDetailsScreen({
    required this.request,
    super.key,
  });

  String _dateLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _openProposalStudio(BuildContext context, Proposal? existing) {
    if (existing != null && !existing.status.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You already submitted an offer for this issue. '
            'Only one offer is allowed per technician.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      HDCPageRoute<void>(
        page: ProposalStudioScreen(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<HDCAuthProvider>();
    final identity = auth.identity;
    final canAccess = auth.authenticated &&
        identity != null &&
        identity.hasPlatformRole(HDCPlatformRole.technician);

    if (!canAccess) {
      return const Scaffold(
        body: Center(
          child: Text('Registered technician access required.'),
        ),
      );
    }

    final technicianId = identity.id;
    final marketplace = context.watch<TechnicianMarketplaceProvider>();
    final proposalProvider = context.watch<ProposalProvider>();
    final summary = proposalProvider.summaryForRequest(request.id);
    final ownProposal = proposalProvider.latestForTechnicianRequest(
      technicianId: technicianId,
      requestId: request.id,
    );
    final displayProposalCount = summary.received > 0
        ? summary.received
        : request.id.startsWith('SR-MKT-')
            ? request.offerCount
            : 0;
    final isSaved = marketplace.isSaved(request.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Opportunity'),
        actions: [
          IconButton(
            tooltip: isSaved ? 'Remove from saved' : 'Save request',
            onPressed: () => marketplace.toggleSaved(request.id),
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ownProposal != null) ...[
              Text(
                ownProposal.status.canEdit
                    ? 'Resume this draft. HDC keeps one offer per issue.'
                    : 'Your offer is already recorded. A second offer cannot '
                        'be created for the same issue.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 9),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ownProposal == null || ownProposal.status.canEdit
                    ? () => _openProposalStudio(context, ownProposal)
                    : null,
                icon: Icon(
                  ownProposal?.status.canEdit == true
                      ? Icons.edit_outlined
                      : ownProposal == null
                          ? Icons.send_outlined
                          : Icons.check_circle_outline,
                ),
                label: Text(
                  ownProposal == null
                      ? 'Prepare Offer'
                      : ownProposal.status.canEdit
                          ? 'Resume Offer Draft'
                          : 'Offer ${ownProposal.status.label}',
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 9,
                            runSpacing: 9,
                            children: [
                              _Badge(
                                label: request.urgency.label,
                                emphasized: request.urgency ==
                                        ServiceRequestUrgency.urgent ||
                                    request.urgency ==
                                        ServiceRequestUrgency.emergency,
                              ),
                              _Badge(label: request.categoryName),
                              _Badge(label: request.status.label),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            request.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Posted by ${request.customerName} • ${request.id}',
                            style: const TextStyle(
                              color: HDCColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            request.description,
                            style: const TextStyle(height: 1.6),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final itemWidth = width >= 650
                                  ? (width - 14) / 2
                                  : width;
                              return Wrap(
                                spacing: 14,
                                runSpacing: 14,
                                children: [
                                  _InfoCard(
                                    width: itemWidth,
                                    icon: Icons.location_on_outlined,
                                    label: 'Service location',
                                    value: request.location,
                                  ),
                                  _InfoCard(
                                    width: itemWidth,
                                    icon: Icons.event_outlined,
                                    label: 'Preferred schedule',
                                    value:
                                        '${_dateLabel(request.preferredDate)} • '
                                        '${request.preferredTime}',
                                  ),
                                  _InfoCard(
                                    width: itemWidth,
                                    icon: Icons.payments_outlined,
                                    label: 'Customer budget',
                                    value: request.budgetLabel,
                                  ),
                                  _InfoCard(
                                    width: itemWidth,
                                    icon: Icons.local_offer_outlined,
                                    label: 'Current competition',
                                    value: displayProposalCount == 1
                                        ? '1 proposal submitted'
                                        : '$displayProposalCount proposals submitted',
                                  ),
                                  if (ownProposal != null)
                                    _InfoCard(
                                      width: itemWidth,
                                      icon: Icons.description_outlined,
                                      label: 'Your proposal',
                                      value: ownProposal.status.label,
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.smart_toy_outlined,
                            color: HDCColors.secondary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nexus Opportunity Insight',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  proposalProvider.technicianNexusInsight(
                                    requestId: request.id,
                                    technicianId: technicianId,
                                  ),
                                  style: const TextStyle(
                                    color: HDCColors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    margin: EdgeInsets.zero,
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: HDCColors.info,
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'For privacy, exact contact details remain hidden '
                              'until the customer accepts an offer. Keep all job '
                              'communication and agreements inside HDC.',
                              style: TextStyle(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _Badge extends StatelessWidget {
  final String label;
  final bool emphasized;

  const _Badge({
    required this.label,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? HDCColors.danger : HDCColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HDCColors.background,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: HDCColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: HDCColors.secondary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: HDCColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
