import '../../models/proposal.dart';
import '../../models/proposal_acceptance_result.dart';
import '../../models/service_request.dart';
import '../../models/transaction_seed.dart';
import '../../repositories/proposal_repository.dart';
import '../../repositories/service_request_repository.dart';
import '../../repositories/transaction_seed_repository.dart';

class ProposalAcceptanceService {
  final ProposalRepository proposalRepository;
  final ServiceRequestRepository serviceRequestRepository;
  final TransactionSeedRepository transactionSeedRepository;

  const ProposalAcceptanceService({
    required this.proposalRepository,
    required this.serviceRequestRepository,
    required this.transactionSeedRepository,
  });

  Future<ProposalAcceptanceResult> accept({
    required String proposalId,
    required String actingCustomerId,
  }) async {
    final proposal = proposalRepository.byId(proposalId);
    if (proposal == null) {
      throw StateError('The selected proposal no longer exists.');
    }

    final request = serviceRequestRepository.byId(proposal.requestId);
    if (request == null) {
      throw StateError('The service request no longer exists.');
    }

    if (request.customerId != actingCustomerId) {
      throw StateError('Only the request owner can accept this proposal.');
    }

    final existingSeed =
        transactionSeedRepository.byRequestId(request.id);
    final acceptedAlready = proposalRepository
        .byRequestId(request.id)
        .where((item) => item.status == ProposalStatus.accepted)
        .toList(growable: false);

    if (existingSeed != null || acceptedAlready.isNotEmpty) {
      if (acceptedAlready.length == 1 &&
          acceptedAlready.first.id == proposal.id &&
          existingSeed?.proposalId == proposal.id) {
        return ProposalAcceptanceResult(
          acceptedProposal: acceptedAlready.first,
          updatedRequest: request,
          transactionSeed: existingSeed!,
          competingProposalsClosed: proposalRepository
              .byRequestId(request.id)
              .where((item) => item.status == ProposalStatus.declined)
              .length,
        );
      }
      throw StateError(
        'A technician has already been selected for this request.',
      );
    }

    if (!proposal.status.isActive) {
      throw StateError('This proposal is no longer eligible for acceptance.');
    }

    if (request.status != ServiceRequestStatus.open &&
        request.status != ServiceRequestStatus.receivingOffers) {
      throw StateError(
        'This service request is no longer accepting proposals.',
      );
    }

    final originalProposals =
        proposalRepository.byRequestId(request.id).toList(growable: false);
    final now = DateTime.now();

    final accepted = proposal.copyWith(
      status: ProposalStatus.accepted,
      viewedAt: proposal.viewedAt ?? now,
      acceptedAt: now,
    );

    final competing = originalProposals
        .where((item) => item.id != proposal.id && item.status.isActive)
        .toList(growable: false);

    final updatedRequest = request.copyWith(
      status: ServiceRequestStatus.technicianSelected,
      updatedAt: now,
    );

    final seed = TransactionSeed(
      id: 'TXN-SEED-${now.millisecondsSinceEpoch}',
      requestId: request.id,
      proposalId: proposal.id,
      customerId: request.customerId,
      technicianId: proposal.technicianId,
      acceptedEstimate: proposal.estimatedTotal,
      status: TransactionSeedStatus.readyForWorkspace,
      createdAt: now,
    );

    var seedCreated = false;
    try {
      await proposalRepository.update(accepted);

      for (final item in competing) {
        await proposalRepository.update(
          item.copyWith(
            status: ProposalStatus.declined,
            declinedAt: now,
          ),
        );
      }

      await serviceRequestRepository.update(updatedRequest);
      await transactionSeedRepository.create(seed);
      seedCreated = true;

      return ProposalAcceptanceResult(
        acceptedProposal: accepted,
        updatedRequest: updatedRequest,
        transactionSeed: seed,
        competingProposalsClosed: competing.length,
      );
    } on Object {
      // Local beta repositories cannot provide a true cross-repository
      // database transaction, so restore the captured state on failure.
      // The production backend must perform this operation transactionally.
      if (seedCreated) {
        try {
          await transactionSeedRepository.delete(seed.id);
        } on Object {
          // Best-effort rollback; original error remains authoritative.
        }
      }

      try {
        await serviceRequestRepository.update(request);
      } on Object {
        // Best-effort rollback.
      }

      for (final original in originalProposals) {
        try {
          await proposalRepository.update(original);
        } on Object {
          // Best-effort rollback.
        }
      }

      rethrow;
    }
  }
}
