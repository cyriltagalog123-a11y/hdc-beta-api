import 'proposal.dart';

enum ProposalComparisonMetric {
  estimatedTotal,
  earliestArrival,
  warranty,
  rating,
  hdcTenure,
  completedJobs,
  quality,
}

extension ProposalComparisonMetricDetails on ProposalComparisonMetric {
  String get label {
    switch (this) {
      case ProposalComparisonMetric.estimatedTotal:
        return 'Lowest estimate';
      case ProposalComparisonMetric.earliestArrival:
        return 'Fastest arrival';
      case ProposalComparisonMetric.warranty:
        return 'Longest warranty';
      case ProposalComparisonMetric.rating:
        return 'Highest rating';
      case ProposalComparisonMetric.hdcTenure:
        return 'Longest HDC tenure';
      case ProposalComparisonMetric.completedJobs:
        return 'Most completed jobs';
      case ProposalComparisonMetric.quality:
        return 'Highest proposal quality';
    }
  }
}

class ProposalComparisonEntry {
  final Proposal proposal;
  final int hdcTenureYears;

  const ProposalComparisonEntry({
    required this.proposal,
    required this.hdcTenureYears,
  });
}

class ProposalComparisonResult {
  final String requestId;
  final List<ProposalComparisonEntry> entries;
  final Map<ProposalComparisonMetric, List<String>> leaderProposalIds;

  const ProposalComparisonResult({
    required this.requestId,
    required this.entries,
    required this.leaderProposalIds,
  });

  bool isLeader(
    String proposalId,
    ProposalComparisonMetric metric,
  ) {
    return leaderProposalIds[metric]?.contains(proposalId) ?? false;
  }

  List<ProposalComparisonMetric> leadersFor(String proposalId) {
    return ProposalComparisonMetric.values
        .where((metric) => isLeader(proposalId, metric))
        .toList(growable: false);
  }
}
