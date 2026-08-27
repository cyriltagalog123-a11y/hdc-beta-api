import '../../models/proposal.dart';
import '../../models/service_request.dart';

class CustomerOfferEntry {
  final ServiceRequest request;
  final Proposal proposal;

  const CustomerOfferEntry({
    required this.request,
    required this.proposal,
  });
}

class CustomerOfferCatalog {
  const CustomerOfferCatalog();

  List<CustomerOfferEntry> entriesFor({
    required String customerId,
    required List<ServiceRequest> requests,
    required List<Proposal> proposals,
  }) {
    final ownedRequests = <String, ServiceRequest>{
      for (final request in requests)
        if (request.customerId == customerId) request.id: request,
    };

    final entries = proposals
        .where((proposal) => proposal.status != ProposalStatus.draft)
        .where((proposal) => proposal.status != ProposalStatus.withdrawn)
        .map((proposal) {
          final request = ownedRequests[proposal.requestId];
          if (request == null) return null;
          return CustomerOfferEntry(request: request, proposal: proposal);
        })
        .whereType<CustomerOfferEntry>()
        .toList(growable: false);

    entries.sort(
      (a, b) =>
          b.proposal.latestLifecycleAt.compareTo(a.proposal.latestLifecycleAt),
    );
    return entries;
  }
}
