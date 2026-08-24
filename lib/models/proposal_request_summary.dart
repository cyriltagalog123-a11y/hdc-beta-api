class ProposalRequestSummary {
  final int received;
  final int submitted;
  final int viewed;
  final int shortlisted;
  final int accepted;
  final int declined;
  final int expired;
  final int withdrawn;
  final DateTime? latestActivityAt;

  const ProposalRequestSummary({
    required this.received,
    required this.submitted,
    required this.viewed,
    required this.shortlisted,
    required this.accepted,
    required this.declined,
    required this.expired,
    required this.withdrawn,
    this.latestActivityAt,
  });

  const ProposalRequestSummary.empty()
      : received = 0,
        submitted = 0,
        viewed = 0,
        shortlisted = 0,
        accepted = 0,
        declined = 0,
        expired = 0,
        withdrawn = 0,
        latestActivityAt = null;

  int get viewedOrBeyond => viewed + shortlisted + accepted;

  int get active => submitted + viewed + shortlisted;

  bool get hasProposals => received > 0;

  bool get customerIsReviewing => viewedOrBeyond > 0 && accepted == 0;

  String get customerStatusLabel {
    if (accepted > 0) return 'Technician selected';
    if (shortlisted > 0) return 'Reviewing shortlist';
    if (viewedOrBeyond > 0) return 'Reviewing proposals';
    if (received > 0) return 'Proposals received';
    return 'Awaiting proposals';
  }

  String get technicianMarketplaceLabel {
    if (accepted > 0) return 'Technician selected';
    if (shortlisted > 0) return 'Customer shortlisting';
    if (viewedOrBeyond > 0) return 'Customer reviewing';
    if (received > 0) return '$received proposal${received == 1 ? '' : 's'} submitted';
    return 'No proposals yet';
  }
}
