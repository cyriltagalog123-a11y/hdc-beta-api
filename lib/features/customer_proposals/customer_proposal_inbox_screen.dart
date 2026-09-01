import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/workflow/hdc_workflow_refresh.dart';
import '../../models/proposal.dart';
import '../../models/proposal_request_summary.dart';
import '../../models/service_request.dart';
import '../../providers/hdc_workflow_sync_provider.dart';
import '../../providers/proposal_provider.dart';
import 'customer_proposal_comparison_screen.dart';
import 'customer_proposal_details_screen.dart';

enum ProposalInboxSort {
  recommended,
  lowestPrice,
  highestRating,
  fastestArrival,
  longestWarranty,
  highestQuality,
  mostExperienced,
}

extension on ProposalInboxSort {
  String get label {
    switch (this) {
      case ProposalInboxSort.recommended:
        return 'Recommended';
      case ProposalInboxSort.lowestPrice:
        return 'Lowest price';
      case ProposalInboxSort.highestRating:
        return 'Highest rating';
      case ProposalInboxSort.fastestArrival:
        return 'Fastest arrival';
      case ProposalInboxSort.longestWarranty:
        return 'Longest warranty';
      case ProposalInboxSort.highestQuality:
        return 'Highest quality';
      case ProposalInboxSort.mostExperienced:
        return 'Longest HDC tenure';
    }
  }
}

class CustomerProposalInboxScreen extends StatefulWidget {
  final ServiceRequest request;

  const CustomerProposalInboxScreen({required this.request, super.key});

  @override
  State<CustomerProposalInboxScreen> createState() =>
      _CustomerProposalInboxScreenState();
}

class _CustomerProposalInboxScreenState
    extends State<CustomerProposalInboxScreen> {
  ProposalInboxSort _sort = ProposalInboxSort.recommended;
  bool _shortlistedOnly = false;
  final Set<String> _selectedProposalIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(refreshHdcWorkflow(context));
    });
  }

  List<Proposal> _visible(List<Proposal> source) {
    final proposals = source
        .where((proposal) => proposal.status != ProposalStatus.draft)
        .where((proposal) => proposal.status != ProposalStatus.withdrawn)
        .where(
          (proposal) =>
              !_shortlistedOnly ||
              proposal.status == ProposalStatus.shortlisted,
        )
        .toList();

    switch (_sort) {
      case ProposalInboxSort.recommended:
        proposals.sort((a, b) {
          final quality = b.qualityScore.compareTo(a.qualityScore);
          if (quality != 0) return quality;
          return b.reputation.rating.compareTo(a.reputation.rating);
        });
        break;
      case ProposalInboxSort.lowestPrice:
        proposals.sort((a, b) => a.estimatedTotal.compareTo(b.estimatedTotal));
        break;
      case ProposalInboxSort.highestRating:
        proposals.sort(
          (a, b) => b.reputation.rating.compareTo(a.reputation.rating),
        );
        break;
      case ProposalInboxSort.fastestArrival:
        proposals.sort(
          (a, b) => a.earliestArrival.compareTo(b.earliestArrival),
        );
        break;
      case ProposalInboxSort.longestWarranty:
        proposals.sort((a, b) => b.warrantyDays.compareTo(a.warrantyDays));
        break;
      case ProposalInboxSort.highestQuality:
        proposals.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
        break;
      case ProposalInboxSort.mostExperienced:
        proposals.sort(
          (a, b) => a.reputation.memberSinceYear.compareTo(
            b.reputation.memberSinceYear,
          ),
        );
        break;
    }
    return proposals;
  }

  void _toggleComparisonSelection(Proposal proposal) {
    if (!proposal.status.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only active submitted, viewed, or shortlisted proposals '
            'can be compared.',
          ),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedProposalIds.contains(proposal.id)) {
        _selectedProposalIds.remove(proposal.id);
        return;
      }

      if (_selectedProposalIds.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can compare up to three proposals at a time.'),
          ),
        );
        return;
      }

      _selectedProposalIds.add(proposal.id);
    });
  }

  void _openComparison() {
    if (_selectedProposalIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least two proposals to compare.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      HDCPageRoute<void>(
        page: CustomerProposalComparisonScreen(
          request: widget.request,
          proposalIds: _selectedProposalIds.toList(growable: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProposalProvider>();
    final sync = context.watch<HdcWorkflowSyncProvider?>();
    final all = provider.forRequest(widget.request.id);
    final proposals = _visible(all);
    final summary = provider.summaryForRequest(widget.request.id);
    final shortlistedCount = summary.shortlisted;
    final isRefreshing = provider.isLoading || (sync?.isSyncing ?? false);
    final loadError = provider.lastError ?? sync?.lastError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Professional Service Proposals'),
        actions: [
          IconButton(
            tooltip: 'Refresh proposals',
            onPressed: isRefreshing ? null : () => refreshHdcWorkflow(context),
            icon: isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: isRefreshing && all.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RequestHeader(
                          request: widget.request,
                          summary: summary,
                        ),
                        const SizedBox(height: 18),
                        _Toolbar(
                          sort: _sort,
                          shortlistedOnly: _shortlistedOnly,
                          shortlistedCount: shortlistedCount,
                          onSortChanged: (value) =>
                              setState(() => _sort = value),
                          onShortlistedChanged: (value) =>
                              setState(() => _shortlistedOnly = value),
                        ),
                        if (_selectedProposalIds.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _ComparisonSelectionBar(
                            selectedCount: _selectedProposalIds.length,
                            onClear: () =>
                                setState(() => _selectedProposalIds.clear()),
                            onCompare: _openComparison,
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (loadError != null && all.isEmpty)
                          _ErrorState(
                            onRetry: () => refreshHdcWorkflow(context),
                          )
                        else if (proposals.isEmpty)
                          _EmptyState(shortlistedOnly: _shortlistedOnly)
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final twoColumns = constraints.maxWidth >= 900;
                              if (!twoColumns) {
                                return Column(
                                  children: [
                                    for (final proposal in proposals) ...[
                                      _ProposalCard(
                                        proposal: proposal,
                                        highlights: _highlights(proposal, all),
                                        selected: _selectedProposalIds.contains(
                                          proposal.id,
                                        ),
                                        comparisonEligible:
                                            proposal.status.isActive,
                                        onToggleCompare: () =>
                                            _toggleComparisonSelection(
                                              proposal,
                                            ),
                                        onOpen: () => _open(proposal),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  ],
                                );
                              }
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: proposals
                                    .map(
                                      (proposal) => SizedBox(
                                        width: (constraints.maxWidth - 16) / 2,
                                        child: _ProposalCard(
                                          proposal: proposal,
                                          highlights: _highlights(
                                            proposal,
                                            all,
                                          ),
                                          selected: _selectedProposalIds
                                              .contains(proposal.id),
                                          comparisonEligible:
                                              proposal.status.isActive,
                                          onToggleCompare: () =>
                                              _toggleComparisonSelection(
                                                proposal,
                                              ),
                                          onOpen: () => _open(proposal),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _open(Proposal proposal) async {
    await Navigator.of(context).push(
      HDCPageRoute<void>(
        page: CustomerProposalDetailsScreen(proposalId: proposal.id),
      ),
    );
  }

  List<String> _highlights(Proposal proposal, List<Proposal> all) {
    final eligible = all
        .where((item) => item.status != ProposalStatus.draft)
        .where((item) => item.status != ProposalStatus.withdrawn)
        .toList();
    if (eligible.isEmpty) return const [];

    final labels = <String>[];
    if (proposal.estimatedTotal ==
        eligible.map((e) => e.estimatedTotal).reduce((a, b) => a < b ? a : b)) {
      labels.add('Lowest price');
    }
    if (proposal.earliestArrival ==
        eligible
            .map((e) => e.earliestArrival)
            .reduce((a, b) => a.isBefore(b) ? a : b)) {
      labels.add('Fastest arrival');
    }
    if (proposal.warrantyDays ==
        eligible.map((e) => e.warrantyDays).reduce((a, b) => a > b ? a : b)) {
      labels.add('Longest warranty');
    }
    if (proposal.qualityScore ==
        eligible.map((e) => e.qualityScore).reduce((a, b) => a > b ? a : b)) {
      labels.add('Highest quality');
    }
    if (proposal.reputation.rating ==
        eligible
            .map((e) => e.reputation.rating)
            .reduce((a, b) => a > b ? a : b)) {
      labels.add('Top rated');
    }
    return labels.take(3).toList(growable: false);
  }
}

class _RequestHeader extends StatelessWidget {
  final ServiceRequest request;
  final ProposalRequestSummary summary;

  const _RequestHeader({required this.request, required this.summary});

  @override
  Widget build(BuildContext context) {
    return HDCFlowHero(
      eyebrow: 'Customer offer inbox',
      title: request.title,
      description:
          '${request.categoryName} • ${request.location}. Review '
          'complete terms, compare active offers, and accept only after the '
          'final confirmation step.',
      icon: Icons.mark_email_unread_outlined,
      tags: [
        HDCFlowTag(
          label: '${summary.received} received',
          icon: Icons.local_offer_outlined,
        ),
        HDCFlowTag(
          label: '${summary.viewedOrBeyond} viewed',
          icon: Icons.visibility_outlined,
          color: HDCColors.info,
        ),
        HDCFlowTag(
          label: '${summary.shortlisted} shortlisted',
          icon: Icons.favorite_outline_rounded,
          color: HDCColors.warm,
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  final ProposalInboxSort sort;
  final bool shortlistedOnly;
  final int shortlistedCount;
  final ValueChanged<ProposalInboxSort> onSortChanged;
  final ValueChanged<bool> onShortlistedChanged;

  const _Toolbar({
    required this.sort,
    required this.shortlistedOnly,
    required this.shortlistedCount,
    required this.onSortChanged,
    required this.onShortlistedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 19),
                const SizedBox(width: 9),
                DropdownButton<ProposalInboxSort>(
                  value: sort,
                  underline: const SizedBox.shrink(),
                  items: ProposalInboxSort.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                ),
              ],
            ),
            FilterChip(
              selected: shortlistedOnly,
              onSelected: onShortlistedChanged,
              avatar: const Icon(Icons.favorite_outline, size: 17),
              label: Text('Shortlisted ($shortlistedCount)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonSelectionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onCompare;

  const _ComparisonSelectionBar({
    required this.selectedCount,
    required this.onClear,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HDCColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HDCColors.secondary.withValues(alpha: 0.18)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Text(
            '$selectedCount of 3 proposals selected',
            style: const TextStyle(fontWeight: FontWeight.w800),
          );
          final actions = HDCResponsiveActions(
            breakpoint: 300,
            actions: [
              TextButton(onPressed: onClear, child: const Text('Clear')),
              FilledButton.icon(
                onPressed: selectedCount >= 2 ? onCompare : null,
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare'),
              ),
            ],
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [label, const SizedBox(height: 10), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 16),
              SizedBox(width: 300, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final Proposal proposal;
  final List<String> highlights;
  final bool selected;
  final bool comparisonEligible;
  final VoidCallback onToggleCompare;
  final VoidCallback onOpen;

  const _ProposalCard({
    required this.proposal,
    required this.highlights,
    required this.selected,
    required this.comparisonEligible,
    required this.onToggleCompare,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final reputation = proposal.reputation;
    return Card(
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
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: HDCColors.secondary.withValues(
                      alpha: 0.10,
                    ),
                    child: Text(
                      reputation.technicianName.isEmpty
                          ? 'T'
                          : reputation.technicianName
                                .substring(0, 1)
                                .toUpperCase(),
                      style: const TextStyle(
                        color: HDCColors.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                reputation.technicianName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (reputation.isVerified) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified,
                                size: 17,
                                color: HDCColors.secondary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '★ ${reputation.rating.toStringAsFixed(1)}  •  '
                          '${reputation.completedJobs} completed jobs',
                          style: const TextStyle(
                            color: HDCColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (comparisonEligible) ...[
                    Checkbox(
                      value: selected,
                      onChanged: (_) => onToggleCompare(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  _ProposalStatusChip(status: proposal.status),
                ],
              ),
              if (highlights.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: highlights
                      .map((label) => _HighlightChip(label: label))
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Total estimate',
                      value: _money(proposal.estimatedTotal),
                      emphasized: true,
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Warranty',
                      value: proposal.warrantyDays == 0
                          ? 'None'
                          : '${proposal.warrantyDays} days',
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Quality',
                      value: '${proposal.qualityScore}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                proposal.diagnosis,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 17),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('View Professional Proposal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _money(double amount) => 'PHP ${amount.toStringAsFixed(0)}';
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _Metric({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: HDCColors.textSecondary, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 17 : 14,
            fontWeight: FontWeight.w900,
            color: emphasized ? HDCColors.secondary : HDCColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final String label;
  const _HighlightChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: HDCColors.success.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '✓ $label',
        style: const TextStyle(
          color: HDCColors.success,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProposalStatusChip extends StatelessWidget {
  final ProposalStatus status;
  const _ProposalStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ProposalStatus.submitted => HDCColors.info,
      ProposalStatus.viewed => HDCColors.secondary,
      ProposalStatus.shortlisted => Colors.deepPurple,
      ProposalStatus.accepted => HDCColors.success,
      ProposalStatus.declined ||
      ProposalStatus.expired ||
      ProposalStatus.withdrawn => HDCColors.danger,
      ProposalStatus.draft => HDCColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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

class _EmptyState extends StatelessWidget {
  final bool shortlistedOnly;
  const _EmptyState({required this.shortlistedOnly});

  @override
  Widget build(BuildContext context) {
    return HDCEmptyState(
      icon: shortlistedOnly
          ? Icons.favorite_border
          : Icons.mark_email_unread_outlined,
      title: shortlistedOnly
          ? 'No shortlisted proposals yet'
          : 'No professional proposals yet',
      description: shortlistedOnly
          ? 'Open a proposal and shortlist the technicians you are considering.'
          : 'Submitted technician proposals will appear here for review.',
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: HDCColors.danger,
          ),
          const SizedBox(height: 12),
          const Text('Proposals could not be loaded.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
