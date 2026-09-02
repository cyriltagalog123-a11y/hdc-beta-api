import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/proposals/customer_offer_catalog.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/workflow/hdc_workflow_refresh.dart';
import '../../models/proposal.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/hdc_workflow_sync_provider.dart';
import '../../providers/proposal_provider.dart';
import '../../providers/service_request_provider.dart';
import 'customer_proposal_details_screen.dart';

class CustomerOffersScreen extends StatefulWidget {
  const CustomerOffersScreen({super.key});

  @override
  State<CustomerOffersScreen> createState() => _CustomerOffersScreenState();
}

class _CustomerOffersScreenState extends State<CustomerOffersScreen> {
  static const _catalog = CustomerOfferCatalog();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(refreshHdcWorkflow(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<HDCAuthProvider>();
    final identity = auth.identity;
    if (!auth.authenticated || auth.guestMode || identity == null) {
      return const Scaffold(
        body: Center(child: Text('Registered customer access required.')),
      );
    }

    final requestProvider = context.watch<ServiceRequestProvider>();
    final proposalProvider = context.watch<ProposalProvider>();
    final sync = context.watch<HdcWorkflowSyncProvider?>();
    final entries = _catalog.entriesFor(
      customerId: identity.id,
      requests: requestProvider.requests,
      proposals: proposalProvider.proposals,
    );
    final requestCount = entries
        .map((entry) => entry.request.id)
        .toSet()
        .length;
    final isRefreshing =
        requestProvider.isLoading ||
        proposalProvider.isLoading ||
        (sync?.isSyncing ?? false);
    final loadError =
        requestProvider.lastError ??
        proposalProvider.lastError ??
        sync?.lastError;

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Offers Received'),
        actions: [
          IconButton(
            tooltip: 'Refresh offers',
            onPressed: isRefreshing ? null : () => refreshHdcWorkflow(context),
            icon: isRefreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: isRefreshing && entries.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : loadError != null && entries.isEmpty
            ? _OffersLoadError(onRetry: () => refreshHdcWorkflow(context))
            : entries.isEmpty
            ? const _EmptyOffers()
            : RefreshIndicator(
                onRefresh: () => refreshHdcWorkflow(context),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                  itemCount: entries.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _OffersHeader(
                        offerCount: entries.length,
                        requestCount: requestCount,
                      );
                    }
                    final entry = entries[index - 1];
                    return _CustomerOfferCard(
                      entry: entry,
                      onOpen: () {
                        Navigator.of(context).push(
                          HDCPageRoute<void>(
                            page: CustomerProposalDetailsScreen(
                              proposalId: entry.proposal.id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _OffersHeader extends StatelessWidget {
  final int offerCount;
  final int requestCount;

  const _OffersHeader({required this.offerCount, required this.requestCount});

  @override
  Widget build(BuildContext context) {
    return HDCFlowHero(
      eyebrow: 'Customer offers',
      title: '$offerCount technician ${offerCount == 1 ? 'offer' : 'offers'}',
      description:
          'All offers tied to your service requests remain visible '
          'here. Open one to review its full terms, status, and acceptance '
          'options.',
      icon: Icons.local_offer_outlined,
      tags: [
        HDCFlowTag(
          label:
              '$requestCount service '
              '${requestCount == 1 ? 'request' : 'requests'}',
          icon: Icons.assignment_outlined,
        ),
        HDCFlowTag(
          label: '$offerCount total offers',
          icon: Icons.inbox_outlined,
          color: HDCColors.warm,
        ),
      ],
    );
  }
}

class _CustomerOfferCard extends StatelessWidget {
  final CustomerOfferEntry entry;
  final VoidCallback onOpen;

  const _CustomerOfferCard({required this.entry, required this.onOpen});

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
    final local = value.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final proposal = entry.proposal;
    final request = entry.request;
    final statusColor = _proposalStatusColor(proposal.status);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.local_offer_outlined, color: statusColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${request.categoryName} • ${request.id}',
                          style: const TextStyle(
                            color: HDCColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ProposalStatusChip(
                    label: proposal.status.label,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                proposal.reputation.technicianName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 18,
                runSpacing: 9,
                children: [
                  _OfferMeta(
                    icon: Icons.payments_outlined,
                    label: 'PHP ${proposal.estimatedTotal.toStringAsFixed(0)}',
                  ),
                  _OfferMeta(
                    icon: Icons.event_available_outlined,
                    label: 'Available ${_dateLabel(proposal.earliestArrival)}',
                  ),
                  _OfferMeta(
                    icon: Icons.workspace_premium_outlined,
                    label: '${proposal.qualityScore}% quality',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Open Offer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ProposalStatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _OfferMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OfferMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: HDCColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: HDCColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: HDCColors.textSecondary,
            ),
            SizedBox(height: 18),
            Text(
              'No offers received yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 10),
            Text(
              'Technician offers will appear here after they are submitted.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HDCColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _OffersLoadError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _OffersLoadError({required this.onRetry});

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
              'Offers could not be loaded.',
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

Color _proposalStatusColor(ProposalStatus status) {
  switch (status) {
    case ProposalStatus.accepted:
      return HDCColors.success;
    case ProposalStatus.declined:
    case ProposalStatus.expired:
    case ProposalStatus.withdrawn:
      return HDCColors.danger;
    case ProposalStatus.shortlisted:
      return HDCColors.info;
    case ProposalStatus.draft:
    case ProposalStatus.submitted:
    case ProposalStatus.viewed:
      return HDCColors.warning;
  }
}
