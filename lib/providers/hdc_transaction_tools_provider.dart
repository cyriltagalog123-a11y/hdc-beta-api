import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';
import '../models/transaction_toolbox.dart';

class HdcTransactionToolsProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;

  final Map<String, HdcTransactionToolbox> _toolboxes = {};
  String? _boundUserId;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _disposed = false;
  Object? _lastError;
  int _bindingVersion = 0;

  HdcTransactionToolsProvider({this.client});

  bool get backendAvailable => client != null;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get lastError => _lastError;

  HdcTransactionToolbox? forTransaction(String transactionId) =>
      _toolboxes[transactionId];

  void bindUser(String? userId) {
    if (_disposed || _boundUserId == userId) return;
    _boundUserId = userId;
    _bindingVersion += 1;
    _toolboxes.clear();
    _lastError = null;
    scheduleMicrotask(_announce);
  }

  Future<HdcTransactionToolbox> refresh(String transactionId) async {
    final api = _requireClient();
    final userId = _requireUser();
    final version = _bindingVersion;
    _isLoading = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.get('${_path(transactionId)}/toolbox');
      final toolbox = _toolbox(response);
      _cache(toolbox, transactionId, userId, version);
      return toolbox;
    } on Object catch (error) {
      if (_isCurrent(userId, version)) _lastError = error;
      rethrow;
    } finally {
      if (_isCurrent(userId, version)) {
        _isLoading = false;
        _announce();
      }
    }
  }

  Future<HdcTransactionToolbox> proposeSchedule({
    required String transactionId,
    required DateTime proposedFor,
    String note = '',
    String? clientReference,
  }) {
    return _post(
      transactionId,
      'schedule-changes',
      {
        'clientReference': clientReference ?? newClientReference('schedule'),
        'proposedFor': proposedFor.toUtc().toIso8601String(),
        'note': note.trim(),
      },
    );
  }

  Future<HdcTransactionToolbox> decideSchedule({
    required String transactionId,
    required String scheduleId,
    required String action,
    String note = '',
  }) {
    return _put(
      transactionId,
      'schedule-changes/${Uri.encodeComponent(scheduleId)}',
      {'action': action, 'note': note.trim()},
    );
  }

  Future<HdcTransactionToolbox> proposeChangeOrder({
    required String transactionId,
    required int serviceFeeMinor,
    required int partsCostMinor,
    required String reason,
    String currency = 'PHP',
    String? clientReference,
  }) {
    return _post(
      transactionId,
      'change-orders',
      {
        'clientReference': clientReference ?? newClientReference('price'),
        'serviceFeeMinor': serviceFeeMinor,
        'partsCostMinor': partsCostMinor,
        'reason': reason.trim(),
        'currency': currency,
      },
    );
  }

  Future<HdcTransactionToolbox> decideChangeOrder({
    required String transactionId,
    required String changeOrderId,
    required String action,
    String note = '',
  }) {
    return _put(
      transactionId,
      'change-orders/${Uri.encodeComponent(changeOrderId)}',
      {'action': action, 'note': note.trim()},
    );
  }

  Future<HdcTransactionToolbox> recordException({
    required String transactionId,
    required String exceptionType,
    required String reason,
    String? clientReference,
  }) {
    return _post(
      transactionId,
      'exceptions',
      {
        'clientReference': clientReference ?? newClientReference('exception'),
        'exceptionType': exceptionType,
        'reason': reason.trim(),
      },
    );
  }

  Future<HdcTransactionToolbox> recordPayment({
    required String transactionId,
    required int amountMinor,
    required String paymentMethod,
    String currency = 'PHP',
    String note = '',
    String? externalReference,
    String? clientReference,
  }) {
    return _post(
      transactionId,
      'payments',
      {
        'clientReference': clientReference ?? newClientReference('payment'),
        'amountMinor': amountMinor,
        'currency': currency,
        'paymentMethod': paymentMethod,
        'note': note.trim(),
        'externalReference': externalReference?.trim(),
      },
    );
  }

  Future<HdcTransactionToolbox> updatePayment({
    required String transactionId,
    required String paymentId,
    required String action,
    int? amountMinor,
    String note = '',
  }) {
    return _put(
      transactionId,
      'payments/${Uri.encodeComponent(paymentId)}',
      {'action': action, 'amountMinor': amountMinor, 'note': note.trim()},
    );
  }

  Future<HdcTransactionToolbox> createDocument({
    required String transactionId,
    required String documentType,
    required String title,
    required String content,
    String? disputeId,
    String? clientReference,
  }) {
    return _post(
      transactionId,
      'documents',
      {
        'clientReference': clientReference ?? newClientReference('document'),
        'documentType': documentType,
        'title': title.trim(),
        'content': content.trim(),
        'disputeId': disputeId,
      },
    );
  }

  Future<HdcTransactionToolbox> removeDocument({
    required String transactionId,
    required String documentId,
  }) {
    return _delete(
      transactionId,
      'documents/${Uri.encodeComponent(documentId)}',
    );
  }

  Future<HdcTransactionToolbox> openDispute({
    required String transactionId,
    required String reasonCode,
    required String summary,
    required String requestedOutcome,
    String? clientReference,
  }) {
    return _post(
      transactionId,
      'disputes',
      {
        'clientReference': clientReference ?? newClientReference('dispute'),
        'reasonCode': reasonCode,
        'summary': summary.trim(),
        'requestedOutcome': requestedOutcome,
      },
    );
  }

  Future<HdcTransactionToolbox> updateDispute({
    required String transactionId,
    required String disputeId,
    required String action,
    required String message,
  }) {
    return _put(
      transactionId,
      'disputes/${Uri.encodeComponent(disputeId)}',
      {'action': action, 'message': message.trim()},
    );
  }

  String newClientReference(String category) {
    return 'HDC-$category-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<HdcTransactionToolbox> _post(
    String transactionId,
    String suffix,
    Map<String, Object?> body,
  ) {
    return _mutate(
      transactionId,
      () => _requireClient().post('${_path(transactionId)}/$suffix', body: body),
    );
  }

  Future<HdcTransactionToolbox> _put(
    String transactionId,
    String suffix,
    Map<String, Object?> body,
  ) {
    return _mutate(
      transactionId,
      () => _requireClient().put('${_path(transactionId)}/$suffix', body: body),
    );
  }

  Future<HdcTransactionToolbox> _delete(
    String transactionId,
    String suffix,
  ) {
    return _mutate(
      transactionId,
      () => _requireClient().delete('${_path(transactionId)}/$suffix'),
    );
  }

  Future<HdcTransactionToolbox> _mutate(
    String transactionId,
    Future<Map<String, dynamic>> Function() request,
  ) async {
    if (_isSaving) {
      throw StateError('Another service-workspace change is still saving.');
    }
    final userId = _requireUser();
    final version = _bindingVersion;
    _isSaving = true;
    _lastError = null;
    _announce();
    try {
      final toolbox = _toolbox(await request());
      _cache(toolbox, transactionId, userId, version);
      return toolbox;
    } on Object catch (error) {
      if (_isCurrent(userId, version)) _lastError = error;
      rethrow;
    } finally {
      if (_isCurrent(userId, version)) {
        _isSaving = false;
        _announce();
      }
    }
  }

  HdcTransactionToolbox _toolbox(Map<String, dynamic> response) {
    final value = response['toolbox'];
    if (value is! Map) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned incomplete service-workspace data.',
      );
    }
    return HdcTransactionToolbox.fromJson(
      value.map((key, value) => MapEntry('$key', value)),
    );
  }

  void _cache(
    HdcTransactionToolbox toolbox,
    String transactionId,
    String userId,
    int version,
  ) {
    if (!_isCurrent(userId, version)) {
      throw StateError('The HDC account changed while the workspace was loading.');
    }
    if (toolbox.transactionId != transactionId) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned data for a different service transaction.',
      );
    }
    _toolboxes[transactionId] = toolbox;
    _lastError = null;
  }

  HdcWorkflowApiClient _requireClient() {
    final api = client;
    if (api == null) {
      throw StateError('Service-workspace tools require the HDC API.');
    }
    return api;
  }

  String _requireUser() {
    final userId = _boundUserId;
    if (userId == null) {
      throw const HdcWorkflowException(
        code: 'authentication_required',
        message: 'Sign in to use service-workspace tools.',
      );
    }
    return userId;
  }

  bool _isCurrent(String userId, int version) =>
      !_disposed && _boundUserId == userId && _bindingVersion == version;

  String _path(String transactionId) =>
      '/api/service-transactions/${Uri.encodeComponent(transactionId)}';

  void _announce() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
