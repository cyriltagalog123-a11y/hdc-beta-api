import '../models/proposal_acceptance_result.dart';

abstract interface class ProposalAcceptanceGateway {
  Future<ProposalAcceptanceResult> accept({
    required String proposalId,
    required String actingCustomerId,
  });
}
