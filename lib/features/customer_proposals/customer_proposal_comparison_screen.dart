import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/proposal.dart';
import '../../models/proposal_comparison.dart';
import '../../models/service_request.dart';
import '../../providers/proposal_provider.dart';
import 'customer_proposal_details_screen.dart';
import 'proposal_acceptance_flow.dart';

class CustomerProposalComparisonScreen extends StatelessWidget {
  final ServiceRequest request;
  final List<String> proposalIds;

  const CustomerProposalComparisonScreen({
    required this.request,
    required this.proposalIds,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProposalProvider>();

    ProposalComparisonResult result;

    try {
      result = provider.compareProposals(
        requestId: request.id,
        proposalIds: proposalIds,
      );
    } on Object catch (error) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Compare Proposals'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 56,
                    color: HDCColors.warning,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Comparison is no longer available',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: HDCColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Back to Proposals',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text(
          'Professional Proposal Comparison',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1280,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ComparisonHeader(
                    request: request,
                    count: result.entries.length,
                  ),

                  const SizedBox(height: 16),

                  _NexusComparisonInsight(
                    message: provider.comparisonNexusInsight(
                      result,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const _DecisionNotice(),

                  const SizedBox(height: 22),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        for (
                          var index = 0;
                          index < result.entries.length;
                          index++
                        ) ...[
                          SizedBox(
                            width: 340,
                            child: _ComparisonColumn(
                              entry: result.entries[index],
                              result: result,
                              onViewProposal: () {
                                Navigator.of(context).push(
                                  HDCPageRoute<void>(
                                    page:
                                        CustomerProposalDetailsScreen(
                                      proposalId:
                                          result
                                              .entries[index]
                                              .proposal
                                              .id,
                                    ),
                                  ),
                                );
                              },
                              onAcceptProposal: () {
                                startProposalAcceptanceFlow(
                                  context,
                                  proposal:
                                      result
                                          .entries[index]
                                          .proposal,
                                );
                              },
                            ),
                          ),

                          if (index !=
                              result.entries.length - 1)
                            const SizedBox(
                              width: 16,
                            ),
                        ],
                      ],
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

class _ComparisonHeader extends StatelessWidget {
  final ServiceRequest request;
  final int count;

  const _ComparisonHeader({
    required this.request,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.compare_arrows,
              color: HDCColors.secondary,
              size: 30,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    request.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w800,
                        ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '$count proposals selected • '
                    '${request.categoryName}',
                    style: const TextStyle(
                      color:
                          HDCColors.textSecondary,
                    ),
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

class _NexusComparisonInsight
    extends StatelessWidget {
  final String message;

  const _NexusComparisonInsight({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HDCColors.secondary.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              HDCColors.secondary.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.smart_toy_outlined,
            color: HDCColors.secondary,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'Nexus: $message',
              style: const TextStyle(
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionNotice extends StatelessWidget {
  const _DecisionNotice();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.balance_outlined,
              color: HDCColors.info,
            ),

            SizedBox(width: 12),

            Expanded(
              child: Text(
                'HDC highlights objective differences only. '
                'A lower estimate, faster arrival, longer '
                'warranty, or higher rating does not '
                'automatically make one proposal the best '
                'choice for you.',
                style: TextStyle(
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonColumn
    extends StatelessWidget {
  final ProposalComparisonEntry entry;
  final ProposalComparisonResult result;
  final VoidCallback onViewProposal;
  final VoidCallback onAcceptProposal;

  const _ComparisonColumn({
    required this.entry,
    required this.result,
    required this.onViewProposal,
    required this.onAcceptProposal,
  });

  @override
  Widget build(BuildContext context) {
    final proposal = entry.proposal;
    final reputation = proposal.reputation;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      HDCColors.secondary
                          .withValues(
                    alpha: 0.10,
                  ),
                  child: Text(
                    reputation
                            .technicianName
                            .isEmpty
                        ? 'T'
                        : reputation
                            .technicianName
                            .substring(
                              0,
                              1,
                            )
                            .toUpperCase(),
                    style: const TextStyle(
                      color:
                          HDCColors.secondary,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    reputation.technicianName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),

                if (reputation.isVerified)
                  const Icon(
                    Icons.verified,
                    color:
                        HDCColors.secondary,
                    size: 19,
                  ),
              ],
            ),

            const SizedBox(height: 18),

            _MetricRow(
              label: 'Total estimate',
              value: _money(
                proposal.estimatedTotal,
              ),
              highlighted: result.isLeader(
                proposal.id,
                ProposalComparisonMetric
                    .estimatedTotal,
              ),
            ),

            _MetricRow(
              label: 'Earliest arrival',
              value: _dateTime(
                proposal.earliestArrival,
              ),
              highlighted: result.isLeader(
                proposal.id,
                ProposalComparisonMetric
                    .earliestArrival,
              ),
            ),

            _MetricRow(
              label: 'Warranty',
              value:
                  proposal.warrantyDays == 0
                      ? 'None'
                      : '${proposal.warrantyDays} days',
              highlighted: result.isLeader(
                proposal.id,
                ProposalComparisonMetric
                    .warranty,
              ),
            ),

            _MetricRow(
              label: 'Rating',
              value:
                  '${reputation.rating.toStringAsFixed(1)} / 5.0',
              highlighted: result.isLeader(
                proposal.id,
                ProposalComparisonMetric
                    .rating,
              ),
            ),

            _MetricRow(
              label: 'HDC tenure',
              value:
                  entry.hdcTenureYears == 0
                      ? 'New HDC member'
                      : '${entry.hdcTenureYears} '
                          '${entry.hdcTenureYears == 1 ? 'year' : 'years'}',
              highlighted: result.isLeader(
                proposal.id,
                ProposalComparisonMetric
                    .hdcTenure,
              ),
            ),

            _MetricRow(
              label: 'Completed jobs',
              value:
                  '${reputation.completedJobs}',
              highlighted: result.isLeader(
                proposal.id,
                ProposalComparisonMetric
                    .completedJobs,
              ),
            ),

            _MetricRow(
              label: 'Proposal quality',
              value:
                  '${proposal.qualityScore}%',
              highlighted: result.isLeader(
                proposal.id,
                ProposalComparisonMetric
                    .quality,
              ),
            ),

            _MetricRow(
              label: 'Repair duration',
              value: _duration(
                proposal
                    .estimatedDurationMinutes,
              ),
              highlighted: false,
            ),

            _MetricRow(
              label: 'Success rate',
              value:
                  '${reputation.successRate.toStringAsFixed(0)}%',
              highlighted: false,
            ),

            const SizedBox(height: 18),

            if (result
                .leadersFor(proposal.id)
                .isNotEmpty) ...[
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: result
                    .leadersFor(
                      proposal.id,
                    )
                    .map(
                      (metric) => Chip(
                        avatar: const Icon(
                          Icons
                              .check_circle_outline,
                          size: 16,
                        ),
                        label: Text(
                          metric.label,
                        ),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 18),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewProposal,
                icon: const Icon(
                  Icons.description_outlined,
                ),
                label: const Text(
                  'View Full Proposal',
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    proposal.status.isActive
                        ? onAcceptProposal
                        : null,
                icon: const Icon(
                  Icons.check_circle_outline,
                ),
                label: Text(
                  proposal.status ==
                          ProposalStatus.accepted
                      ? 'Accepted'
                      : 'Accept Proposal',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _money(double value) {
    return 'PHP ${value.toStringAsFixed(0)}';
  }

  String _dateTime(DateTime value) {
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

    final hour = value.hour == 0
        ? 12
        : value.hour > 12
            ? value.hour - 12
            : value.hour;

    final minute =
        value.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final period =
        value.hour >= 12
            ? 'PM'
            : 'AM';

    return '${months[value.month - 1]} '
        '${value.day}, '
        '${value.year} • '
        '$hour:$minute $period';
  }

  String _duration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }

    final hours =
        minutes ~/ 60;

    final remaining =
        minutes % 60;

    if (remaining == 0) {
      return '$hours '
          '${hours == 1 ? 'hr' : 'hrs'}';
    }

    return '$hours hr $remaining min';
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: highlighted
            ? HDCColors.success.withValues(
                alpha: 0.08,
              )
            : HDCColors.background,
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: highlighted
              ? HDCColors.success
                  .withValues(
                    alpha: 0.28,
                  )
              : HDCColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color:
                        HDCColors.textSecondary,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          if (highlighted)
            const Padding(
              padding: EdgeInsets.only(
                left: 8,
              ),
              child: Icon(
                Icons.check_circle,
                color: HDCColors.success,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}