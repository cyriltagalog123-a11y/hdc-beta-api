import '../../models/proposal.dart';
import '../../models/proposal_comparison.dart';

class ProposalComparisonService {
  const ProposalComparisonService();

  static const int minimumProposalCount = 2;
  static const int maximumProposalCount = 3;

  bool isEligible(Proposal proposal) {
    return proposal.status.isActive;
  }

  ProposalComparisonResult compare({
    required String requestId,
    required List<Proposal> proposals,
    DateTime? now,
  }) {
    if (proposals.length < minimumProposalCount ||
        proposals.length > maximumProposalCount) {
      throw ArgumentError(
        'Compare between $minimumProposalCount and '
        '$maximumProposalCount proposals.',
      );
    }

    final uniqueIds = proposals.map((proposal) => proposal.id).toSet();

    if (uniqueIds.length != proposals.length) {
      throw ArgumentError('A proposal cannot be compared more than once.');
    }

    if (proposals.any((proposal) => proposal.requestId != requestId)) {
      throw ArgumentError(
        'All compared proposals must belong to the same service request.',
      );
    }

    if (proposals.any((proposal) => !isEligible(proposal))) {
      throw StateError(
        'Only active submitted, viewed, or shortlisted proposals '
        'can be compared.',
      );
    }

    final currentYear = (now ?? DateTime.now()).year;
    final entries = proposals
        .map(
          (proposal) => ProposalComparisonEntry(
            proposal: proposal,
            hdcTenureYears:
                (currentYear - proposal.reputation.memberSinceYear)
                    .clamp(0, currentYear)
                    .toInt(),
          ),
        )
        .toList(growable: false);

    return ProposalComparisonResult(
      requestId: requestId,
      entries: entries,
      leaderProposalIds: {
        ProposalComparisonMetric.estimatedTotal: _leadersByDouble(
          proposals,
          (proposal) => proposal.estimatedTotal,
          preferLower: true,
        ),
        ProposalComparisonMetric.earliestArrival: _leadersByDate(
          proposals,
          (proposal) => proposal.earliestArrival,
          preferEarlier: true,
        ),
        ProposalComparisonMetric.warranty: _leadersByInt(
          proposals,
          (proposal) => proposal.warrantyDays,
        ),
        ProposalComparisonMetric.rating: _leadersByDouble(
          proposals,
          (proposal) => proposal.reputation.rating,
        ),
        ProposalComparisonMetric.hdcTenure: _leadersByInt(
          entries,
          (entry) => entry.hdcTenureYears,
        ),
        ProposalComparisonMetric.completedJobs: _leadersByInt(
          proposals,
          (proposal) => proposal.reputation.completedJobs,
        ),
        ProposalComparisonMetric.quality: _leadersByInt(
          proposals,
          (proposal) => proposal.qualityScore,
        ),
      },
    );
  }

  String nexusTradeoffSummary(ProposalComparisonResult result) {
    final sentences = <String>[];

    _appendUniqueLeaderSentence(
      sentences,
      result,
      ProposalComparisonMetric.estimatedTotal,
      'offers the lowest estimated total',
    );
    _appendUniqueLeaderSentence(
      sentences,
      result,
      ProposalComparisonMetric.earliestArrival,
      'can arrive the earliest',
    );
    _appendUniqueLeaderSentence(
      sentences,
      result,
      ProposalComparisonMetric.warranty,
      'offers the longest warranty',
    );
    _appendUniqueLeaderSentence(
      sentences,
      result,
      ProposalComparisonMetric.rating,
      'has the highest rating',
    );
    _appendUniqueLeaderSentence(
      sentences,
      result,
      ProposalComparisonMetric.quality,
      'has the highest proposal quality score',
    );

    if (sentences.isEmpty) {
      return 'These proposals are closely matched across the current '
          'comparison factors. Review the diagnosis, repair plan, pricing, '
          'schedule, and warranty before deciding.';
    }

    return '${sentences.join(' ')} HDC is highlighting objective differences '
        'only; the final choice remains yours.';
  }

  void _appendUniqueLeaderSentence(
    List<String> sentences,
    ProposalComparisonResult result,
    ProposalComparisonMetric metric,
    String description,
  ) {
    final ids = result.leaderProposalIds[metric] ?? const <String>[];

    if (ids.length != 1) return;

    final proposalId = ids.first;
    ProposalComparisonEntry? entry;

    for (final candidate in result.entries) {
      if (candidate.proposal.id == proposalId) {
        entry = candidate;
        break;
      }
    }

    if (entry == null) return;

    sentences.add('${entry.proposal.reputation.technicianName} $description.');
  }

  List<String> _leadersByInt<T extends Object>(
    List<T> values,
    int Function(T value) selector, {
    bool preferLower = false,
  }) {
    final selectedValues = values.map(selector).toList(growable: false);

    final best = preferLower
        ? selectedValues.reduce((a, b) => a < b ? a : b)
        : selectedValues.reduce((a, b) => a > b ? a : b);

    return [
      for (var index = 0; index < values.length; index++)
        if (selectedValues[index] == best) _idFor(values[index]),
    ];
  }

  List<String> _leadersByDouble<T extends Object>(
    List<T> values,
    double Function(T value) selector, {
    bool preferLower = false,
  }) {
    final selectedValues = values.map(selector).toList(growable: false);

    final best = preferLower
        ? selectedValues.reduce((a, b) => a < b ? a : b)
        : selectedValues.reduce((a, b) => a > b ? a : b);

    const epsilon = 0.000001;

    return [
      for (var index = 0; index < values.length; index++)
        if ((selectedValues[index] - best).abs() < epsilon)
          _idFor(values[index]),
    ];
  }

  List<String> _leadersByDate<T extends Object>(
    List<T> values,
    DateTime Function(T value) selector, {
    required bool preferEarlier,
  }) {
    final selectedValues = values.map(selector).toList(growable: false);

    final best = preferEarlier
        ? selectedValues.reduce((a, b) => a.isBefore(b) ? a : b)
        : selectedValues.reduce((a, b) => a.isAfter(b) ? a : b);

    return [
      for (var index = 0; index < values.length; index++)
        if (selectedValues[index].isAtSameMomentAs(best))
          _idFor(values[index]),
    ];
  }

  String _idFor(Object value) {
    if (value is Proposal) {
      return value.id;
    }

    if (value is ProposalComparisonEntry) {
      return value.proposal.id;
    }

    throw ArgumentError('Unsupported comparison value type.');
  }
}
