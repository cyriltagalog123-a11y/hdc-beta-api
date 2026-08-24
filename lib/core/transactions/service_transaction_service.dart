import '../../models/proposal.dart';
import '../../models/service_request.dart';
import '../../models/service_transaction.dart';
import '../../models/transaction_seed.dart';
import '../../repositories/proposal_repository.dart';
import '../../repositories/service_request_repository.dart';
import '../../repositories/service_transaction_repository.dart';
import '../../repositories/transaction_seed_repository.dart';

class ServiceTransactionService {
  final ServiceTransactionRepository transactionRepository;
  final TransactionSeedRepository seedRepository;
  final ProposalRepository proposalRepository;
  final ServiceRequestRepository serviceRequestRepository;

  const ServiceTransactionService({
    required this.transactionRepository,
    required this.seedRepository,
    required this.proposalRepository,
    required this.serviceRequestRepository,
  });

  Future<List<ServiceTransaction>> consumeReadySeeds() async {
    final created = <ServiceTransaction>[];

    for (final seed in seedRepository.getAll()) {
      if (seed.status != TransactionSeedStatus.readyForWorkspace) {
        continue;
      }

      final transaction = await consumeSeed(seed.id);
      created.add(transaction);
    }

    return created;
  }

  Future<ServiceTransaction> consumeSeed(String seedId) async {
    final seed = seedRepository.byId(seedId);

    if (seed == null) {
      throw StateError('Transaction handoff $seedId was not found.');
    }

    final existing = transactionRepository.bySeedId(seed.id);

    if (existing != null) {
      if (seed.status != TransactionSeedStatus.consumed) {
        await seedRepository.update(
          seed.copyWith(status: TransactionSeedStatus.consumed),
        );
      }
      return existing;
    }

    if (seed.status != TransactionSeedStatus.readyForWorkspace) {
      throw StateError(
        'Transaction handoff ${seed.id} is not ready to be consumed.',
      );
    }

    final proposal = proposalRepository.byId(seed.proposalId);
    final request = serviceRequestRepository.byId(seed.requestId);

    if (proposal == null) {
      throw StateError('Accepted proposal ${seed.proposalId} was not found.');
    }

    if (request == null) {
      throw StateError('Service request ${seed.requestId} was not found.');
    }

    if (proposal.status != ProposalStatus.accepted) {
      throw StateError(
        'Only an accepted proposal can create a service transaction.',
      );
    }

    if (proposal.requestId != request.id ||
        proposal.technicianId != seed.technicianId ||
        request.customerId != seed.customerId) {
      throw StateError(
        'Transaction handoff does not match the accepted service relationship.',
      );
    }

    if (request.status != ServiceRequestStatus.technicianSelected &&
        request.status != ServiceRequestStatus.inProgress) {
      throw StateError(
        'The service request is not ready for a transaction workspace.',
      );
    }

    final now = DateTime.now();
    final transactionId = 'TXN-${now.millisecondsSinceEpoch}';

    final transaction = ServiceTransaction(
      id: transactionId,
      seedId: seed.id,
      requestId: request.id,
      proposalId: proposal.id,
      customerId: request.customerId,
      customerName: request.customerName,
      technicianId: proposal.technicianId,
      technicianName: proposal.reputation.technicianName,
      requestTitle: request.title,
      categoryName: request.categoryName,
      serviceLocation: request.location,
      status: ServiceTransactionStatus.confirmed,
      acceptedTerms: AcceptedServiceTerms(
        serviceFee: proposal.serviceFee,
        estimatedPartsCost: proposal.estimatedPartsCost,
        totalEstimate: proposal.estimatedTotal,
        earliestArrival: proposal.earliestArrival,
        estimatedDurationMinutes: proposal.estimatedDurationMinutes,
        warrantyDays: proposal.warrantyDays,
        diagnosis: proposal.diagnosis,
        repairApproach: proposal.repairApproach,
        professionalNotes: proposal.professionalNotes,
      ),
      activity: [
        ServiceTransactionActivity(
          id: '$transactionId-ACT-1',
          type: ServiceTransactionActivityType.transactionCreated,
          message: 'Service transaction created from the accepted proposal.',
          createdAt: now,
          toStatus: ServiceTransactionStatus.created,
        ),
        ServiceTransactionActivity(
          id: '$transactionId-ACT-2',
          type: ServiceTransactionActivityType.transactionConfirmed,
          message: 'Customer and technician service relationship confirmed.',
          createdAt: now,
          fromStatus: ServiceTransactionStatus.created,
          toStatus: ServiceTransactionStatus.confirmed,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    var transactionCreated = false;

    try {
      await transactionRepository.create(transaction);
      transactionCreated = true;

      await seedRepository.update(
        seed.copyWith(status: TransactionSeedStatus.consumed),
      );

      return transaction;
    } on Object {
      if (transactionCreated) {
        try {
          await transactionRepository.delete(transaction.id);
        } on Object {
          // Best-effort beta rollback. Production uses one DB transaction.
        }
      }
      rethrow;
    }
  }

  Future<ServiceTransaction> transition({
    required String transactionId,
    required ServiceTransactionStatus toStatus,
    required String actorId,
  }) async {
    final current = transactionRepository.byId(transactionId);

    if (current == null) {
      throw StateError('Service transaction $transactionId was not found.');
    }

    final actorRole = current.roleFor(actorId);

    if (actorRole == null) {
      throw StateError(
        'Only a transaction participant can update this service transaction.',
      );
    }

    if (!_isAllowedTransition(current.status, toStatus)) {
      throw StateError(
        'Transaction cannot move from ${current.status.label} '
        'to ${toStatus.label}.',
      );
    }

    if (!_isActorAllowed(
      role: actorRole,
      from: current.status,
      to: toStatus,
    )) {
      throw StateError(
        '${actorRole.label} is not allowed to move this transaction '
        'from ${current.status.label} to ${toStatus.label}.',
      );
    }

    final now = DateTime.now();
    final updated = current.copyWith(
      status: toStatus,
      activity: [
        ...current.activity,
        ServiceTransactionActivity(
          id: '${current.id}-ACT-${current.activity.length + 1}',
          type: _activityTypeFor(toStatus),
          message: _activityMessageFor(toStatus),
          createdAt: now,
          fromStatus: current.status,
          toStatus: toStatus,
          actorId: actorId,
        ),
      ],
      updatedAt: now,
    );

    final request = serviceRequestRepository.byId(current.requestId);
    var transactionUpdated = false;

    try {
      await transactionRepository.update(updated);
      transactionUpdated = true;

      if (request != null) {
        final requestStatus = _requestStatusForTransaction(toStatus);
        if (requestStatus != null && request.status != requestStatus) {
          await serviceRequestRepository.update(
            request.copyWith(
              status: requestStatus,
              updatedAt: now,
            ),
          );
        }
      }

      return updated;
    } on Object {
      if (transactionUpdated) {
        try {
          await transactionRepository.update(current);
        } on Object {
          // Best-effort beta rollback.
        }
      }

      if (request != null) {
        try {
          await serviceRequestRepository.update(request);
        } on Object {
          // Best-effort beta rollback.
        }
      }

      rethrow;
    }
  }

  bool _isActorAllowed({
    required ServiceTransactionParticipantRole role,
    required ServiceTransactionStatus from,
    required ServiceTransactionStatus to,
  }) {
    if (to == ServiceTransactionStatus.disputed) {
      return true;
    }

    if (to == ServiceTransactionStatus.cancelled) {
      return role == ServiceTransactionParticipantRole.customer &&
          from != ServiceTransactionStatus.inProgress &&
          from != ServiceTransactionStatus.awaitingCustomerConfirmation;
    }

    switch (role) {
      case ServiceTransactionParticipantRole.technician:
        return (from == ServiceTransactionStatus.confirmed &&
                to == ServiceTransactionStatus.scheduled) ||
            (from == ServiceTransactionStatus.scheduled &&
                to == ServiceTransactionStatus.technicianEnRoute) ||
            (from == ServiceTransactionStatus.technicianEnRoute &&
                to == ServiceTransactionStatus.arrived) ||
            (from == ServiceTransactionStatus.arrived &&
                to == ServiceTransactionStatus.inProgress) ||
            (from == ServiceTransactionStatus.inProgress &&
                to ==
                    ServiceTransactionStatus.awaitingCustomerConfirmation);
      case ServiceTransactionParticipantRole.customer:
        return from ==
                ServiceTransactionStatus.awaitingCustomerConfirmation &&
            to == ServiceTransactionStatus.completed;
    }
  }

  bool _isAllowedTransition(
    ServiceTransactionStatus from,
    ServiceTransactionStatus to,
  ) {
    if (from.isTerminal || from == ServiceTransactionStatus.disputed) {
      return false;
    }

    if (to == ServiceTransactionStatus.disputed) {
      return true;
    }

    if (to == ServiceTransactionStatus.cancelled) {
      return from != ServiceTransactionStatus.awaitingCustomerConfirmation;
    }

    switch (from) {
      case ServiceTransactionStatus.created:
        return to == ServiceTransactionStatus.confirmed;
      case ServiceTransactionStatus.confirmed:
        return to == ServiceTransactionStatus.scheduled;
      case ServiceTransactionStatus.scheduled:
        return to == ServiceTransactionStatus.technicianEnRoute;
      case ServiceTransactionStatus.technicianEnRoute:
        return to == ServiceTransactionStatus.arrived;
      case ServiceTransactionStatus.arrived:
        return to == ServiceTransactionStatus.inProgress;
      case ServiceTransactionStatus.inProgress:
        return to ==
            ServiceTransactionStatus.awaitingCustomerConfirmation;
      case ServiceTransactionStatus.awaitingCustomerConfirmation:
        return to == ServiceTransactionStatus.completed;
      case ServiceTransactionStatus.completed:
      case ServiceTransactionStatus.cancelled:
      case ServiceTransactionStatus.disputed:
        return false;
    }
  }

  ServiceRequestStatus? _requestStatusForTransaction(
    ServiceTransactionStatus status,
  ) {
    switch (status) {
      case ServiceTransactionStatus.inProgress:
      case ServiceTransactionStatus.awaitingCustomerConfirmation:
        return ServiceRequestStatus.inProgress;
      case ServiceTransactionStatus.completed:
        return ServiceRequestStatus.completed;
      case ServiceTransactionStatus.cancelled:
        return ServiceRequestStatus.cancelled;
      case ServiceTransactionStatus.created:
      case ServiceTransactionStatus.confirmed:
      case ServiceTransactionStatus.scheduled:
      case ServiceTransactionStatus.technicianEnRoute:
      case ServiceTransactionStatus.arrived:
      case ServiceTransactionStatus.disputed:
        return null;
    }
  }

  ServiceTransactionActivityType _activityTypeFor(
    ServiceTransactionStatus status,
  ) {
    switch (status) {
      case ServiceTransactionStatus.disputed:
        return ServiceTransactionActivityType.disputeOpened;
      case ServiceTransactionStatus.cancelled:
        return ServiceTransactionActivityType.cancelled;
      case ServiceTransactionStatus.completed:
        return ServiceTransactionActivityType.completed;
      default:
        return ServiceTransactionActivityType.statusChanged;
    }
  }

  String _activityMessageFor(ServiceTransactionStatus status) {
    switch (status) {
      case ServiceTransactionStatus.scheduled:
        return 'Service schedule confirmed.';
      case ServiceTransactionStatus.technicianEnRoute:
        return 'Technician is on the way.';
      case ServiceTransactionStatus.arrived:
        return 'Technician arrived at the service location.';
      case ServiceTransactionStatus.inProgress:
        return 'Technology service work started.';
      case ServiceTransactionStatus.awaitingCustomerConfirmation:
        return 'Technician marked the service as ready for customer review.';
      case ServiceTransactionStatus.completed:
        return 'Customer confirmed service completion.';
      case ServiceTransactionStatus.cancelled:
        return 'Service transaction cancelled.';
      case ServiceTransactionStatus.disputed:
        return 'A transaction dispute was opened.';
      case ServiceTransactionStatus.created:
        return 'Service transaction created.';
      case ServiceTransactionStatus.confirmed:
        return 'Service transaction confirmed.';
    }
  }
}
