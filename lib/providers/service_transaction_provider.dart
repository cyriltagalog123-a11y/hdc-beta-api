import 'package:flutter/foundation.dart';

import '../core/transactions/service_transaction_service.dart';
import '../models/service_transaction.dart';
import '../repositories/service_transaction_repository.dart';
import '../repositories/service_transaction_transition_gateway.dart';
import '../repositories/transaction_seed_repository.dart';
import 'proposal_provider.dart';
import 'service_request_provider.dart';

class ServiceTransactionProvider extends ChangeNotifier {
  final ServiceTransactionRepository repository;
  final TransactionSeedRepository seedRepository;
  final ServiceTransactionTransitionGateway? transitionGateway;

  ServiceTransactionProvider({
    required this.repository,
    required this.seedRepository,
    this.transitionGateway,
  });

  ServiceTransactionService? _service;
  ProposalProvider? _proposalProvider;
  ServiceRequestProvider? _serviceRequestProvider;

  bool _initialized = false;
  bool _isLoading = true;
  bool _isSaving = false;
  Object? _lastError;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get lastError => _lastError;

  List<ServiceTransaction> get transactions => repository.getAll();

  List<ServiceTransaction> get activeTransactions {
    return transactions
        .where((transaction) => transaction.status.isActive)
        .toList(growable: false);
  }

  List<ServiceTransaction> forCustomer(String customerId) {
    return repository.byCustomerId(customerId);
  }

  List<ServiceTransaction> forTechnician(String technicianId) {
    return repository.byTechnicianId(technicianId);
  }

  ServiceTransaction? byId(String id) => repository.byId(id);

  ServiceTransaction? forRequest(String requestId) {
    return repository.byRequestId(requestId);
  }

  Future<void> bindAndInitialize({
    required ProposalProvider proposalProvider,
    required ServiceRequestProvider serviceRequestProvider,
  }) async {
    _proposalProvider = proposalProvider;
    _serviceRequestProvider = serviceRequestProvider;
    _service = ServiceTransactionService(
      transactionRepository: repository,
      seedRepository: seedRepository,
      proposalRepository: proposalProvider.repository,
      serviceRequestRepository: serviceRequestProvider.repository,
    );

    if (_initialized) return;
    _initialized = true;

    _isLoading = true;
    notifyListeners();

    try {
      await repository.initialize();
      await seedRepository.initialize();
      await _service!.consumeReadySeeds();
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<ServiceTransaction>> syncReadySeeds() async {
    final service = _service;
    if (service == null) {
      throw StateError('Transaction service is not ready yet.');
    }

    final created = await service.consumeReadySeeds();
    _lastError = null;
    notifyListeners();
    return created;
  }

  Future<ServiceTransaction> ensureForSeed(String seedId) async {
    final service = _service;
    if (service == null) {
      throw StateError('Transaction service is not ready yet.');
    }

    _isSaving = true;
    notifyListeners();

    try {
      final transaction = await service.consumeSeed(seedId);
      _lastError = null;
      return transaction;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<ServiceTransaction> transition({
    required String transactionId,
    required ServiceTransactionStatus toStatus,
    required String actorId,
  }) async {
    final service = _service;
    if (service == null) {
      throw StateError('Transaction service is not ready yet.');
    }

    _isSaving = true;
    notifyListeners();

    try {
      final gateway = transitionGateway;
      final result = gateway == null
          ? await service.transition(
              transactionId: transactionId,
              toStatus: toStatus,
              actorId: actorId,
            )
          : await gateway.transition(
              transactionId: transactionId,
              toStatus: toStatus,
              actingUserId: actorId,
            );
      _lastError = null;
      _serviceRequestProvider?.refreshFromRepository();
      _proposalProvider?.refreshFromRepository();
      return result;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void refreshFromRepository() {
    notifyListeners();
  }
}
