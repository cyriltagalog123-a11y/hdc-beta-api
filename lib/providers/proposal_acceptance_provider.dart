import 'package:flutter/foundation.dart';

import '../core/proposals/proposal_acceptance_service.dart';
import '../models/proposal_acceptance_result.dart';
import '../repositories/proposal_acceptance_gateway.dart';
import '../repositories/transaction_seed_repository.dart';
import 'proposal_provider.dart';
import 'service_request_provider.dart';

class ProposalAcceptanceProvider extends ChangeNotifier {
  final TransactionSeedRepository transactionSeedRepository;
  final ProposalAcceptanceGateway? acceptanceGateway;

  ProposalAcceptanceProvider({
    required this.transactionSeedRepository,
    this.acceptanceGateway,
  });

  ProposalAcceptanceService? _service;
  ProposalProvider? _proposalProvider;
  ServiceRequestProvider? _serviceRequestProvider;

  bool _isLoading = true;
  bool _isSaving = false;
  Object? _lastError;
  ProposalAcceptanceResult? _latestResult;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get lastError => _lastError;
  ProposalAcceptanceResult? get latestResult => _latestResult;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await transactionSeedRepository.initialize();
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void bind({
    required ProposalProvider proposalProvider,
    required ServiceRequestProvider serviceRequestProvider,
  }) {
    _proposalProvider = proposalProvider;
    _serviceRequestProvider = serviceRequestProvider;
    _service = ProposalAcceptanceService(
      proposalRepository: proposalProvider.repository,
      serviceRequestRepository: serviceRequestProvider.repository,
      transactionSeedRepository: transactionSeedRepository,
    );
  }

  Future<ProposalAcceptanceResult> acceptProposal({
    required String proposalId,
    required String actingCustomerId,
  }) async {
    final service = _service;
    final gateway = acceptanceGateway;
    if (service == null && gateway == null) {
      throw StateError('Proposal acceptance is not ready yet.');
    }

    _isSaving = true;
    notifyListeners();

    try {
      final result = gateway == null
          ? await service!.accept(
              proposalId: proposalId,
              actingCustomerId: actingCustomerId,
            )
          : await gateway.accept(
              proposalId: proposalId,
              actingCustomerId: actingCustomerId,
            );
      _latestResult = result;
      _lastError = null;
      _proposalProvider?.refreshFromRepository();
      _serviceRequestProvider?.refreshFromRepository();
      return result;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
