import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/proposal.dart';
import '../../providers/proposal_provider.dart';
import 'proposal_acceptance_flow.dart';

class CustomerProposalDetailsScreen extends StatefulWidget {
  final String proposalId;

  const CustomerProposalDetailsScreen({required this.proposalId, super.key});

  @override
  State<CustomerProposalDetailsScreen> createState() =>
      _CustomerProposalDetailsScreenState();
}

class _CustomerProposalDetailsScreenState
    extends State<CustomerProposalDetailsScreen> {
  bool _markedViewed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_markedViewed) return;
    _markedViewed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final proposal = context.read<ProposalProvider>().byId(widget.proposalId);
      if (proposal?.status == ProposalStatus.submitted) {
        await context.read<ProposalProvider>().markViewed(widget.proposalId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProposalProvider>();
    final proposal = provider.byId(widget.proposalId);

    if (proposal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Professional Proposal')),
        body: const Center(child: Text('This proposal was not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Professional Service Proposal')),
      bottomNavigationBar: _BottomActionBar(
        proposal: proposal,
        isSaving: provider.isSaving,
        onToggleShortlist: () => _toggleShortlist(proposal),
        onAccept: () => startProposalAcceptanceFlow(
          context,
          proposal: proposal,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 850;
                  final main = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TechnicalSection(proposal: proposal),
                      const SizedBox(height: 16),
                      _PricingSection(proposal: proposal),
                      const SizedBox(height: 16),
                      _ScheduleSection(proposal: proposal),
                      const SizedBox(height: 16),
                      _NotesSection(notes: proposal.professionalNotes),
                    ],
                  );
                  final side = Column(
                    children: [
                      _TechnicianCard(proposal: proposal),
                      const SizedBox(height: 16),
                      _QualityCard(score: proposal.qualityScore),
                      const SizedBox(height: 16),
                      _TrustNotice(proposal: proposal),
                    ],
                  );

                  return Column(
                    children: [
                      _Hero(proposal: proposal),
                      const SizedBox(height: 14),
                      _ProposalLifecycleCard(proposal: proposal),
                      const SizedBox(height: 18),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: main),
                            const SizedBox(width: 18),
                            Expanded(flex: 4, child: side),
                          ],
                        )
                      else ...[
                        side,
                        const SizedBox(height: 16),
                        main,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleShortlist(Proposal proposal) async {
    try {
      final provider = context.read<ProposalProvider>();
      if (proposal.status == ProposalStatus.shortlisted) {
        await provider.removeFromShortlist(proposal.id);
      } else {
        await provider.shortlist(proposal.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            proposal.status == ProposalStatus.shortlisted
                ? 'Removed from shortlist.'
                : 'Proposal shortlisted.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update shortlist: $error')),
      );
    }
  }
}

class _Hero extends StatelessWidget {
  final Proposal proposal;
  const _Hero({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: HDCColors.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 18,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PROFESSIONAL SERVICE PROPOSAL',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                proposal.reputation.technicianName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 7),
              Text(
                'Proposal ${proposal.id}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'TOTAL ESTIMATE',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
              Text(
                'PHP ${proposal.estimatedTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                proposal.status.label,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _ProposalLifecycleCard extends StatelessWidget {
  final Proposal proposal;

  const _ProposalLifecycleCard({
    required this.proposal,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (proposal.status) {
      ProposalStatus.submitted => HDCColors.info,
      ProposalStatus.viewed => HDCColors.secondary,
      ProposalStatus.shortlisted => Colors.deepPurple,
      ProposalStatus.accepted => HDCColors.success,
      ProposalStatus.declined ||
      ProposalStatus.expired ||
      ProposalStatus.withdrawn => HDCColors.danger,
      ProposalStatus.draft => HDCColors.textSecondary,
    };

    final statusTime = switch (proposal.status) {
      ProposalStatus.submitted => proposal.submittedAt,
      ProposalStatus.viewed => proposal.viewedAt,
      ProposalStatus.shortlisted => proposal.shortlistedAt,
      ProposalStatus.accepted => proposal.acceptedAt,
      ProposalStatus.declined => proposal.declinedAt,
      ProposalStatus.expired => proposal.expiredAt,
      ProposalStatus.withdrawn => proposal.withdrawnAt,
      ProposalStatus.draft => proposal.updatedAt,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _iconFor(proposal.status),
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Proposal Status',
                    style: TextStyle(
                      color: HDCColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    proposal.status.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (statusTime != null)
              Text(
                _timeLabel(statusTime),
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ProposalStatus status) {
    switch (status) {
      case ProposalStatus.draft:
        return Icons.edit_note_outlined;
      case ProposalStatus.submitted:
        return Icons.send_outlined;
      case ProposalStatus.viewed:
        return Icons.visibility_outlined;
      case ProposalStatus.shortlisted:
        return Icons.favorite_outline;
      case ProposalStatus.accepted:
        return Icons.check_circle_outline;
      case ProposalStatus.declined:
        return Icons.remove_circle_outline;
      case ProposalStatus.expired:
        return Icons.timer_off_outlined;
      case ProposalStatus.withdrawn:
        return Icons.undo_outlined;
    }
  }

  String _timeLabel(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${time.month}/${time.day}/${time.year}';
  }
}

class _TechnicianCard extends StatelessWidget {
  final Proposal proposal;
  const _TechnicianCard({required this.proposal});

  @override
  Widget build(BuildContext context) {
    final tech = proposal.reputation;
    final experience = DateTime.now().year - tech.memberSinceYear;
    return _SectionCard(
      title: 'Technician Profile',
      icon: Icons.engineering_outlined,
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: HDCColors.secondary.withValues(alpha: 0.10),
            child: Text(
              tech.technicianName.isEmpty
                  ? 'T'
                  : tech.technicianName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 23,
                color: HDCColors.secondary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  tech.technicianName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              if (tech.isVerified) ...[
                const SizedBox(width: 5),
                const Icon(Icons.verified, color: HDCColors.secondary, size: 18),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _ProfileLine(label: 'Rating', value: '★ ${tech.rating.toStringAsFixed(1)}'),
          _ProfileLine(label: 'Completed jobs', value: '${tech.completedJobs}'),
          _ProfileLine(label: 'Success rate', value: '${tech.successRate.toStringAsFixed(0)}%'),
          _ProfileLine(label: 'Experience', value: '$experience years'),
          _ProfileLine(
            label: 'Typical response',
            value: '${tech.averageResponseMinutes} min',
          ),
        ],
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: HDCColors.textSecondary)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TechnicalSection extends StatelessWidget {
  final Proposal proposal;
  const _TechnicalSection({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Technical Assessment',
      icon: Icons.troubleshoot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TextBlock(label: 'Initial diagnosis', text: proposal.diagnosis),
          const SizedBox(height: 20),
          _TextBlock(label: 'Repair approach', text: proposal.repairApproach),
        ],
      ),
    );
  }
}

class _PricingSection extends StatelessWidget {
  final Proposal proposal;
  const _PricingSection({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Pricing Breakdown',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _PriceRow(label: 'Professional service fee', amount: proposal.serviceFee),
          _PriceRow(
            label: proposal.partsArrangement.label,
            amount: proposal.estimatedPartsCost ?? 0,
          ),
          const Divider(height: 28),
          _PriceRow(label: 'Estimated total', amount: proposal.estimatedTotal, total: true),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool total;
  const _PriceRow({required this.label, required this.amount, this.total = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: total ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            'PHP ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: total ? 18 : 14,
              color: total ? HDCColors.secondary : HDCColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  final Proposal proposal;
  const _ScheduleSection({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Schedule and Warranty',
      icon: Icons.event_available_outlined,
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _InfoTile(
            icon: Icons.schedule,
            label: 'Earliest arrival',
            value: _dateTime(proposal.earliestArrival),
          ),
          _InfoTile(
            icon: Icons.timelapse,
            label: 'Estimated duration',
            value: _duration(proposal.estimatedDurationMinutes),
          ),
          _InfoTile(
            icon: Icons.shield_outlined,
            label: 'Service warranty',
            value: proposal.warrantyDays == 0
                ? 'No warranty included'
                : '${proposal.warrantyDays} days',
          ),
        ],
      ),
    );
  }

  String _dateTime(DateTime value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = value.hour == 0 ? 12 : value.hour > 12 ? value.hour - 12 : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${months[value.month - 1]} ${value.day}, ${value.year} • $hour:$minute $suffix';
  }

  String _duration(int minutes) {
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours == 0) return '$remaining minutes';
    if (remaining == 0) return '$hours hour${hours == 1 ? '' : 's'}';
    return '$hours hr $remaining min';
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: HDCColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HDCColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: HDCColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: HDCColors.textSecondary, fontSize: 10)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  final String notes;
  const _NotesSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Professional Notes',
      icon: Icons.notes_outlined,
      child: Text(
        notes.trim().isEmpty ? 'No additional notes were provided.' : notes,
        style: const TextStyle(height: 1.6),
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  final int score;
  const _QualityCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Proposal Quality',
      icon: Icons.insights_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$score%', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(
                score >= 85 ? 'Excellent' : score >= 65 ? 'Strong' : 'Standard',
                style: const TextStyle(color: HDCColors.secondary, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 11),
          LinearProgressIndicator(value: score / 100, minHeight: 8),
          const SizedBox(height: 11),
          const Text(
            'Quality reflects the completeness of pricing, assessment, schedule, warranty, and professional notes.',
            style: TextStyle(color: HDCColors.textSecondary, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _TrustNotice extends StatelessWidget {
  final Proposal proposal;
  const _TrustNotice({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: HDCColors.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HDCColors.info.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: HDCColors.info, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Review the diagnosis, scope, price, schedule, and warranty carefully. Proposal acceptance will be added in a later sprint.',
              style: TextStyle(fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String label;
  final String text;
  const _TextBlock({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: HDCColors.textSecondary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Text(text, style: const TextStyle(height: 1.6)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

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
                Icon(icon, color: HDCColors.secondary),
                const SizedBox(width: 9),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final Proposal proposal;
  final bool isSaving;
  final VoidCallback onToggleShortlist;
  final VoidCallback onAccept;

  const _BottomActionBar({
    required this.proposal,
    required this.isSaving,
    required this.onToggleShortlist,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final shortlisted = proposal.status == ProposalStatus.shortlisted;
    final canShortlist = proposal.status == ProposalStatus.submitted ||
        proposal.status == ProposalStatus.viewed ||
        shortlisted;
    return SafeArea(
      child: Material(
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'PHP ${proposal.estimatedTotal.toStringAsFixed(0)} total estimate',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedButton.icon(
                onPressed: !canShortlist || isSaving ? null : onToggleShortlist,
                icon: Icon(shortlisted ? Icons.favorite : Icons.favorite_border),
                label: Text(shortlisted ? 'Remove Shortlist' : 'Shortlist'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: proposal.status.isActive && !isSaving
                    ? onAccept
                    : null,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  proposal.status == ProposalStatus.accepted
                      ? 'Accepted'
                      : 'Accept Proposal',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
