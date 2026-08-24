import 'proposal.dart';
import 'service_request.dart';
import 'transaction_seed.dart';

class ProposalAcceptanceResult {
  final Proposal acceptedProposal;
  final ServiceRequest updatedRequest;
  final TransactionSeed transactionSeed;
  final int competingProposalsClosed;

  const ProposalAcceptanceResult({
    required this.acceptedProposal,
    required this.updatedRequest,
    required this.transactionSeed,
    required this.competingProposalsClosed,
  });
}
