import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';
import '../models/proposal.dart';
import '../models/proposal_acceptance_result.dart';
import '../models/service_request.dart';
import '../models/service_transaction.dart';
import '../models/transaction_seed.dart';
import 'proposal_acceptance_gateway.dart';
import 'proposal_repository.dart';
import 'service_request_repository.dart';
import 'service_transaction_repository.dart';
import 'service_transaction_transition_gateway.dart';
import 'transaction_seed_repository.dart';

class HdcApiWorkflowStore
    extends ChangeNotifier
    implements
        ProposalAcceptanceGateway,
        ServiceTransactionTransitionGateway {
  final HdcWorkflowApiClient client;

  final List<ServiceRequest> _serviceRequests = [];
  final List<Proposal> _proposals = [];
  final List<TransactionSeed> _transactionSeeds = [];
  final List<ServiceTransaction> _serviceTransactions = [];

  bool _initialized = false;
  Future<void>? _refreshing;
  int? _refreshingBindingVersion;
  String? _boundUserId;
  int _bindingVersion = 0;
  bool _disposed = false;

  HdcApiWorkflowStore({required this.client});

  List<ServiceRequest> get serviceRequests =>
      List<ServiceRequest>.unmodifiable(_serviceRequests);
  List<Proposal> get proposals => List<Proposal>.unmodifiable(_proposals);
  List<TransactionSeed> get transactionSeeds =>
      List<TransactionSeed>.unmodifiable(_transactionSeeds);
  List<ServiceTransaction> get serviceTransactions =>
      List<ServiceTransaction>.unmodifiable(_serviceTransactions);

  void bindUser(String? userId, {bool announce = true}) {
    if (_disposed || _boundUserId == userId) return;
    _boundUserId = userId;
    _bindingVersion += 1;
    clear(announce: false);
    if (announce) _announceChange();
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (_boundUserId == null || !await client.hasSession) {
      clear();
      _initialized = true;
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    final userId = _boundUserId;
    final bindingVersion = _bindingVersion;
    final active = _refreshing;
    if (active != null && _refreshingBindingVersion == bindingVersion) {
      await active;
      return;
    }

    final future = _performRefresh(userId, bindingVersion);
    _refreshing = future;
    _refreshingBindingVersion = bindingVersion;
    try {
      await future;
    } finally {
      if (identical(_refreshing, future)) {
        _refreshing = null;
        _refreshingBindingVersion = null;
      }
    }
  }

  Future<void> _performRefresh(
    String? userId,
    int bindingVersion,
  ) async {
    if (userId == null) {
      if (_bindingVersion == bindingVersion && _boundUserId == null) {
        clear();
        _initialized = true;
      }
      return;
    }

    final hasSession = await client.hasSession;
    if (_bindingVersion != bindingVersion || _boundUserId != userId) return;
    if (!hasSession) {
      clear();
      _initialized = true;
      return;
    }

    final response = await client.get('/api/workflow/bootstrap');
    if (_bindingVersion != bindingVersion || _boundUserId != userId) return;
    final requests = _list(response, 'serviceRequests')
        .map(ServiceRequest.fromJson)
        .toList(growable: false);
    final proposals = _list(response, 'proposals')
        .map(Proposal.fromJson)
        .toList(growable: false);
    final seeds = _list(response, 'transactionSeeds')
        .map(TransactionSeed.fromJson)
        .toList(growable: false);
    final transactions = _list(response, 'serviceTransactions')
        .map(ServiceTransaction.fromJson)
        .toList(growable: false);

    _serviceRequests
      ..clear()
      ..addAll(requests);
    _proposals
      ..clear()
      ..addAll(proposals);
    _transactionSeeds
      ..clear()
      ..addAll(seeds);
    _serviceTransactions
      ..clear()
      ..addAll(transactions);
    _initialized = true;
    _announceChange();
  }

  void clear({bool announce = true}) {
    _serviceRequests.clear();
    _proposals.clear();
    _transactionSeeds.clear();
    _serviceTransactions.clear();
    _initialized = false;
    if (announce) _announceChange();
  }

  void announceCacheChange() {
    _announceChange();
  }

  Future<ServiceRequest> createServiceRequest(ServiceRequest request) async {
    final response = await client.post(
      '/api/service-requests',
      body: request.toJson(),
    );
    final created = ServiceRequest.fromJson(
      _object(response, 'serviceRequest'),
    );
    if (created.id != request.id) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned an invalid service request identifier.',
      );
    }
    _upsert(_serviceRequests, created, (item) => item.id);
    _announceChange();
    return created;
  }

  Future<ServiceRequest> updateServiceRequest(ServiceRequest request) async {
    final response = await client.put(
      '/api/service-requests/${Uri.encodeComponent(request.id)}',
      body: request.toJson(),
    );
    final updated = ServiceRequest.fromJson(
      _object(response, 'serviceRequest'),
    );
    if (updated.id != request.id) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned an invalid service request identifier.',
      );
    }
    final updatedProposals = <Proposal>[];
    for (final value in _list(response, 'updatedProposals')) {
      final proposal = Proposal.fromJson(value);
      if (proposal.requestId != updated.id) {
        throw const HdcWorkflowException(
          code: 'invalid_server_response',
          message: 'HDC returned an invalid proposal relationship.',
        );
      }
      updatedProposals.add(proposal);
    }
    _upsert(_serviceRequests, updated, (item) => item.id);
    for (final proposal in updatedProposals) {
      _upsert(_proposals, proposal, (item) => item.id);
    }
    _announceChange();
    return updated;
  }

  Future<void> deleteServiceRequest(String id) async {
    await client.delete('/api/service-requests/${Uri.encodeComponent(id)}');
    _serviceRequests.removeWhere((item) => item.id == id);
    _announceChange();
  }

  Future<Proposal> createProposal(Proposal proposal) async {
    final response = await client.post(
      '/api/proposals',
      body: proposal.toJson(),
    );
    final created = Proposal.fromJson(_object(response, 'proposal'));
    final request = ServiceRequest.fromJson(
      _object(response, 'updatedRequest'),
    );
    if (created.id != proposal.id ||
        created.requestId != proposal.requestId ||
        request.id != proposal.requestId) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned an invalid proposal relationship.',
      );
    }
    _upsert(_proposals, created, (item) => item.id);
    _upsert(_serviceRequests, request, (item) => item.id);
    _announceChange();
    return created;
  }

  Future<Proposal> updateProposal(Proposal proposal) async {
    final response = await client.put(
      '/api/proposals/${Uri.encodeComponent(proposal.id)}',
      body: proposal.toJson(),
    );
    final updated = Proposal.fromJson(_object(response, 'proposal'));
    final request = ServiceRequest.fromJson(
      _object(response, 'updatedRequest'),
    );
    if (updated.id != proposal.id ||
        updated.requestId != proposal.requestId ||
        request.id != proposal.requestId) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned an invalid proposal relationship.',
      );
    }
    _upsert(_proposals, updated, (item) => item.id);
    _upsert(_serviceRequests, request, (item) => item.id);
    _announceChange();
    return updated;
  }

  Future<void> deleteProposal(String id) async {
    await client.delete('/api/proposals/${Uri.encodeComponent(id)}');
    _proposals.removeWhere((item) => item.id == id);
    _announceChange();
  }

  @override
  Future<ProposalAcceptanceResult> accept({
    required String proposalId,
    required String actingCustomerId,
  }) async {
    final response = await client.post(
      '/api/proposals/${Uri.encodeComponent(proposalId)}/accept',
    );
    final accepted = Proposal.fromJson(
      _object(response, 'acceptedProposal'),
    );
    final request = ServiceRequest.fromJson(
      _object(response, 'updatedRequest'),
    );
    final seed = TransactionSeed.fromJson(
      _object(response, 'transactionSeed'),
    );
    final transaction = ServiceTransaction.fromJson(
      _object(response, 'serviceTransaction'),
    );
    final closedValue = response['competingProposalsClosed'];

    if (accepted.id != proposalId ||
        accepted.requestId != request.id ||
        request.customerId != actingCustomerId ||
        seed.requestId != request.id ||
        seed.proposalId != accepted.id ||
        seed.customerId != actingCustomerId ||
        seed.technicianId != accepted.technicianId ||
        transaction.seedId != seed.id ||
        transaction.requestId != request.id ||
        transaction.proposalId != accepted.id ||
        transaction.customerId != actingCustomerId ||
        transaction.technicianId != accepted.technicianId) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned an invalid transaction relationship.',
      );
    }

    final competing = <Proposal>[];
    for (final value in _list(response, 'competingProposals')) {
      final item = Proposal.fromJson(value);
      if (item.requestId != request.id || item.id == accepted.id) {
        throw const HdcWorkflowException(
          code: 'invalid_server_response',
          message: 'HDC returned an invalid proposal relationship.',
        );
      }
      competing.add(item);
    }
    final closed = closedValue is num ? closedValue.toInt() : -1;
    if (closed < 0 || closed > competing.length) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned an invalid proposal acceptance count.',
      );
    }

    _upsert(_serviceRequests, request, (item) => item.id);
    _upsert(_proposals, accepted, (item) => item.id);
    for (final item in competing) {
      _upsert(_proposals, item, (value) => value.id);
    }
    _upsert(_transactionSeeds, seed, (item) => item.id);
    _upsert(_serviceTransactions, transaction, (item) => item.id);
    _announceChange();

    return ProposalAcceptanceResult(
      acceptedProposal: accepted,
      updatedRequest: request,
      transactionSeed: seed,
      competingProposalsClosed: closed,
    );
  }

  Future<ServiceTransaction> updateServiceTransaction(
    ServiceTransaction transaction,
  ) {
    return _setTransactionStatus(
      transactionId: transaction.id,
      toStatus: transaction.status,
    );
  }

  @override
  Future<ServiceTransaction> transition({
    required String transactionId,
    required ServiceTransactionStatus toStatus,
    required String actingUserId,
  }) {
    return _setTransactionStatus(
      transactionId: transactionId,
      toStatus: toStatus,
      actingUserId: actingUserId,
    );
  }

  Future<ServiceTransaction> _setTransactionStatus({
    required String transactionId,
    required ServiceTransactionStatus toStatus,
    String? actingUserId,
  }) async {
    final response = await client.put(
      '/api/service-transactions/'
      '${Uri.encodeComponent(transactionId)}/status',
      body: {'status': toStatus.name},
    );
    final updated = ServiceTransaction.fromJson(
      _object(response, 'serviceTransaction'),
    );
    final request = ServiceRequest.fromJson(
      _object(response, 'updatedRequest'),
    );
    if (updated.id != transactionId ||
        updated.status != toStatus ||
        request.id != updated.requestId ||
        request.customerId != updated.customerId ||
        (actingUserId != null && !updated.isParticipant(actingUserId))) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned an invalid transaction relationship.',
      );
    }
    _upsert(_serviceTransactions, updated, (item) => item.id);
    _upsert(_serviceRequests, request, (item) => item.id);
    _announceChange();
    return updated;
  }

  Map<String, dynamic> _object(
    Map<String, dynamic> parent,
    String key,
  ) {
    final value = parent[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    throw const HdcWorkflowException(
      code: 'invalid_server_response',
      message: 'HDC returned incomplete workflow data.',
    );
  }

  List<Map<String, dynamic>> _list(
    Map<String, dynamic> parent,
    String key,
  ) {
    final value = parent[key];
    if (value is! List) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned incomplete workflow data.',
      );
    }
    final result = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map) {
        throw const HdcWorkflowException(
          code: 'invalid_server_response',
          message: 'HDC returned malformed workflow data.',
        );
      }
      result.add(Map<String, dynamic>.from(item));
    }
    return List<Map<String, dynamic>>.unmodifiable(result);
  }

  void _upsert<T>(List<T> values, T value, String Function(T) idOf) {
    final index = values.indexWhere((item) => idOf(item) == idOf(value));
    if (index == -1) {
      values.add(value);
    } else {
      values[index] = value;
    }
  }

  void _announceChange() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class HdcApiServiceRequestRepository implements ServiceRequestRepository {
  final HdcApiWorkflowStore store;

  HdcApiServiceRequestRepository(this.store);

  @override
  Future<void> initialize() => store.ensureInitialized();

  @override
  List<ServiceRequest> getAll() {
    final values = [...store.serviceRequests]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<ServiceRequest>.unmodifiable(values);
  }

  @override
  ServiceRequest? byId(String id) {
    for (final item in store.serviceRequests) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> create(ServiceRequest request) async {
    await store.createServiceRequest(request);
  }

  @override
  Future<void> update(ServiceRequest request) async {
    await store.updateServiceRequest(request);
  }

  @override
  Future<void> delete(String id) => store.deleteServiceRequest(id);
}

class HdcApiProposalRepository implements ProposalRepository {
  final HdcApiWorkflowStore store;

  HdcApiProposalRepository(this.store);

  @override
  Future<void> initialize() => store.ensureInitialized();

  @override
  List<Proposal> getAll() {
    final values = [...store.proposals]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<Proposal>.unmodifiable(values);
  }

  @override
  Proposal? byId(String id) {
    for (final item in store.proposals) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  List<Proposal> byRequestId(String requestId) => getAll()
      .where((item) => item.requestId == requestId)
      .toList(growable: false);

  @override
  List<Proposal> byTechnicianId(String technicianId) => getAll()
      .where((item) => item.technicianId == technicianId)
      .toList(growable: false);

  @override
  Future<void> create(Proposal proposal) async {
    await store.createProposal(proposal);
  }

  @override
  Future<void> update(Proposal proposal) async {
    await store.updateProposal(proposal);
  }

  @override
  Future<void> delete(String id) => store.deleteProposal(id);
}

class HdcApiTransactionSeedRepository implements TransactionSeedRepository {
  final HdcApiWorkflowStore store;

  HdcApiTransactionSeedRepository(this.store);

  @override
  Future<void> initialize() => store.ensureInitialized();

  @override
  List<TransactionSeed> getAll() => store.transactionSeeds;

  @override
  TransactionSeed? byId(String id) {
    for (final item in store.transactionSeeds) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  TransactionSeed? byRequestId(String requestId) {
    for (final item in store.transactionSeeds.reversed) {
      if (item.requestId == requestId) return item;
    }
    return null;
  }

  @override
  Future<void> create(TransactionSeed seed) {
    throw UnsupportedError('Transaction handoffs are created by the HDC backend.');
  }

  @override
  Future<void> update(TransactionSeed seed) {
    throw UnsupportedError('Transaction handoffs are updated by the HDC backend.');
  }

  @override
  Future<void> delete(String id) {
    throw UnsupportedError('Transaction handoffs are retained by the HDC backend.');
  }
}

class HdcApiServiceTransactionRepository
    implements ServiceTransactionRepository {
  final HdcApiWorkflowStore store;

  HdcApiServiceTransactionRepository(this.store);

  @override
  Future<void> initialize() => store.ensureInitialized();

  @override
  List<ServiceTransaction> getAll() {
    final values = [...store.serviceTransactions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<ServiceTransaction>.unmodifiable(values);
  }

  @override
  ServiceTransaction? byId(String id) {
    for (final item in store.serviceTransactions) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  ServiceTransaction? bySeedId(String seedId) {
    for (final item in store.serviceTransactions) {
      if (item.seedId == seedId) return item;
    }
    return null;
  }

  @override
  ServiceTransaction? byRequestId(String requestId) {
    for (final item in store.serviceTransactions.reversed) {
      if (item.requestId == requestId) return item;
    }
    return null;
  }

  @override
  List<ServiceTransaction> byCustomerId(String customerId) => getAll()
      .where((item) => item.customerId == customerId)
      .toList(growable: false);

  @override
  List<ServiceTransaction> byTechnicianId(String technicianId) => getAll()
      .where((item) => item.technicianId == technicianId)
      .toList(growable: false);

  @override
  Future<void> create(ServiceTransaction transaction) {
    throw UnsupportedError('Service transactions are created by the HDC backend.');
  }

  @override
  Future<void> update(ServiceTransaction transaction) async {
    await store.updateServiceTransaction(transaction);
  }

  @override
  Future<void> delete(String id) {
    throw UnsupportedError('Service transactions are retained by the HDC backend.');
  }
}
