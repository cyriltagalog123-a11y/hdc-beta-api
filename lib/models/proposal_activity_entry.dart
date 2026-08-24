enum ProposalActivityType {
  requestCreated,
  proposalSubmitted,
  proposalViewed,
  proposalShortlisted,
  proposalAccepted,
  proposalDeclined,
  proposalWithdrawn,
}

class ProposalActivityEntry {
  final String id;
  final String requestId;
  final String? proposalId;
  final ProposalActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;

  const ProposalActivityEntry({
    required this.id,
    required this.requestId,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.proposalId,
  });
}
