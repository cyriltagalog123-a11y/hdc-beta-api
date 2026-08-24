import '../../models/proposal.dart';
import '../../models/proposal_activity_entry.dart';
import '../../models/proposal_request_summary.dart';
import '../../models/service_request.dart';

class ProposalActivityService {
  const ProposalActivityService();

  ProposalRequestSummary summarize(List<Proposal> proposals) {
    var received = 0;
    var submitted = 0;
    var viewed = 0;
    var shortlisted = 0;
    var accepted = 0;
    var declined = 0;
    var expired = 0;
    var withdrawn = 0;
    DateTime? latestActivityAt;

    for (final proposal in proposals) {
      if (proposal.status != ProposalStatus.draft &&
          proposal.status != ProposalStatus.withdrawn) {
        received++;
      }

      switch (proposal.status) {
        case ProposalStatus.draft:
          break;
        case ProposalStatus.submitted:
          submitted++;
          break;
        case ProposalStatus.viewed:
          viewed++;
          break;
        case ProposalStatus.shortlisted:
          shortlisted++;
          break;
        case ProposalStatus.accepted:
          accepted++;
          break;
        case ProposalStatus.declined:
          declined++;
          break;
        case ProposalStatus.expired:
          expired++;
          break;
        case ProposalStatus.withdrawn:
          withdrawn++;
          break;
      }

      final activityAt = proposal.latestLifecycleAt;
      if (latestActivityAt == null || activityAt.isAfter(latestActivityAt)) {
        latestActivityAt = activityAt;
      }
    }

    return ProposalRequestSummary(
      received: received,
      submitted: submitted,
      viewed: viewed,
      shortlisted: shortlisted,
      accepted: accepted,
      declined: declined,
      expired: expired,
      withdrawn: withdrawn,
      latestActivityAt: latestActivityAt,
    );
  }

  List<ProposalActivityEntry> activityForRequest({
    required ServiceRequest request,
    required List<Proposal> proposals,
  }) {
    final entries = <ProposalActivityEntry>[
      ProposalActivityEntry(
        id: 'request-created-${request.id}',
        requestId: request.id,
        type: ProposalActivityType.requestCreated,
        title: 'Request created',
        description: 'Published to the HDC technician marketplace.',
        timestamp: request.createdAt,
      ),
    ];

    for (final proposal in proposals) {
      final technician = proposal.reputation.technicianName;

      if (proposal.submittedAt != null) {
        entries.add(
          ProposalActivityEntry(
            id: '${proposal.id}-submitted',
            requestId: request.id,
            proposalId: proposal.id,
            type: ProposalActivityType.proposalSubmitted,
            title: 'Proposal received',
            description: '$technician submitted a professional proposal.',
            timestamp: proposal.submittedAt!,
          ),
        );
      }

      if (proposal.viewedAt != null) {
        entries.add(
          ProposalActivityEntry(
            id: '${proposal.id}-viewed',
            requestId: request.id,
            proposalId: proposal.id,
            type: ProposalActivityType.proposalViewed,
            title: 'Proposal viewed',
            description: 'You reviewed $technician\'s proposal.',
            timestamp: proposal.viewedAt!,
          ),
        );
      }

      if (proposal.shortlistedAt != null) {
        entries.add(
          ProposalActivityEntry(
            id: '${proposal.id}-shortlisted',
            requestId: request.id,
            proposalId: proposal.id,
            type: ProposalActivityType.proposalShortlisted,
            title: 'Proposal shortlisted',
            description: '$technician was added to your shortlist.',
            timestamp: proposal.shortlistedAt!,
          ),
        );
      }

      if (proposal.acceptedAt != null) {
        entries.add(
          ProposalActivityEntry(
            id: '${proposal.id}-accepted',
            requestId: request.id,
            proposalId: proposal.id,
            type: ProposalActivityType.proposalAccepted,
            title: 'Proposal accepted',
            description: '$technician was selected for this request.',
            timestamp: proposal.acceptedAt!,
          ),
        );
      }

      if (proposal.declinedAt != null) {
        entries.add(
          ProposalActivityEntry(
            id: '${proposal.id}-declined',
            requestId: request.id,
            proposalId: proposal.id,
            type: ProposalActivityType.proposalDeclined,
            title: 'Proposal closed',
            description: '$technician\'s proposal is no longer active.',
            timestamp: proposal.declinedAt!,
          ),
        );
      }

      if (proposal.withdrawnAt != null) {
        entries.add(
          ProposalActivityEntry(
            id: '${proposal.id}-withdrawn',
            requestId: request.id,
            proposalId: proposal.id,
            type: ProposalActivityType.proposalWithdrawn,
            title: 'Proposal withdrawn',
            description: '$technician withdrew the proposal.',
            timestamp: proposal.withdrawnAt!,
          ),
        );
      }
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  String customerNexusInsight(ProposalRequestSummary summary) {
    if (summary.accepted > 0) {
      return 'A technician has been selected. HDC will keep the service '
          'journey organized as the request moves into its next stage.';
    }
    if (summary.shortlisted > 0) {
      return 'You have ${summary.shortlisted} shortlisted '
          'proposal${summary.shortlisted == 1 ? '' : 's'}. '
          'Review price, arrival time, warranty, and technical approach '
          'before making a decision.';
    }
    if (summary.viewedOrBeyond > 0) {
      return 'You have reviewed ${summary.viewedOrBeyond} of '
          '${summary.received} received proposal${summary.received == 1 ? '' : 's'}. '
          'Shortlist the strongest options when you are ready.';
    }
    if (summary.received > 0) {
      return '${summary.received} professional '
          'proposal${summary.received == 1 ? ' is' : 's are'} waiting for review.';
    }
    return 'No professional proposals have arrived yet. HDC will surface '
        'them here as technicians respond.';
  }

  String technicianNexusInsight({
    required ProposalRequestSummary summary,
    Proposal? technicianProposal,
  }) {
    if (technicianProposal == null) {
      if (summary.received >= 5) {
        return 'This request already has ${summary.received} competing proposals. '
            'Review the opportunity carefully before investing time in a response.';
      }
      return 'This request currently has ${summary.received} competing '
          'proposal${summary.received == 1 ? '' : 's'}.';
    }

    switch (technicianProposal.status) {
      case ProposalStatus.draft:
        return 'Your proposal is still a draft and has not been shown to the customer.';
      case ProposalStatus.submitted:
        return 'Your proposal was submitted and is waiting for customer review.';
      case ProposalStatus.viewed:
        return 'Good news. The customer has viewed your proposal.';
      case ProposalStatus.shortlisted:
        return 'Your proposal is shortlisted and remains under consideration.';
      case ProposalStatus.accepted:
        return 'Your proposal was accepted.';
      case ProposalStatus.declined:
        return 'This proposal is no longer under consideration.';
      case ProposalStatus.expired:
        return 'This proposal has expired.';
      case ProposalStatus.withdrawn:
        return 'You withdrew this proposal.';
    }
  }
}
