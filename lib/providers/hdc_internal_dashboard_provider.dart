import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';
import '../models/account_identity.dart';
import '../models/account_recovery_review.dart';
import '../models/hdc_internal_dashboard.dart';
import '../models/platform_role_application.dart';
import '../models/transaction_toolbox.dart';

class HdcInternalDashboardProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;

  String? _boundUserId;
  Set<HDCInternalRole> _boundRoles = const <HDCInternalRole>{};
  HDCInternalDashboardSnapshot? _snapshot;
  List<PlatformRoleApplication> _reviewQueue = const [];
  List<AccountRecoveryReviewRequest> _recoveryReviewQueue = const [];
  List<HdcServiceDispute> _disputeQueue = const [];
  List<HdcDisputeEvent> _disputeEvents = const [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  Object? _lastError;
  int _bindingVersion = 0;
  bool _disposed = false;

  HdcInternalDashboardProvider({this.client});

  bool get hasAccess => _boundUserId != null && _boundRoles.isNotEmpty;
  bool get backendAvailable => client != null;
  HDCInternalDashboardSnapshot? get snapshot => _snapshot;
  Map<String, int> get statistics =>
      _snapshot?.statistics ?? const <String, int>{};
  List<HDCInternalStaffAssignment> get assignments =>
      _snapshot?.assignments ?? const <HDCInternalStaffAssignment>[];
  List<HDCInternalActivity> get recentActivities =>
      _snapshot?.recentActivities ?? const <HDCInternalActivity>[];
  List<PlatformRoleApplication> get reviewQueue =>
      List<PlatformRoleApplication>.unmodifiable(_reviewQueue);
  List<AccountRecoveryReviewRequest> get recoveryReviewQueue =>
      List<AccountRecoveryReviewRequest>.unmodifiable(_recoveryReviewQueue);
  List<HdcServiceDispute> get disputeQueue =>
      List<HdcServiceDispute>.unmodifiable(_disputeQueue);
  List<HdcDisputeEvent> get disputeEvents =>
      List<HdcDisputeEvent>.unmodifiable(_disputeEvents);
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  Object? get lastError => _lastError;

  HDCInternalDashboardPermissions get permissions {
    final current = _snapshot?.permissions;
    if (current != null) return current;
    return HDCInternalDashboardPermissions(
      canApprovePlatformRoles:
          _boundRoles.any((role) => role.canApprovePlatformRoles),
      canReviewAccountRecovery:
          _boundRoles.any((role) => role.canApprovePlatformRoles),
      canManageInternalStructure:
          _boundRoles.any((role) => role.canManageInternalStructure),
      hasPrivilegedResourceAccess:
          _boundRoles.any((role) => role.hasPrivilegedResourceAccess),
      canModerateCommunity:
          _boundRoles.any((role) => role.canModerateCommunity),
    );
  }

  void bindIdentity(AccountIdentity? identity) {
    if (_disposed) return;
    final userId = identity?.id;
    final roles = identity?.internalRoles ?? const <HDCInternalRole>{};
    if (_boundUserId == userId && setEquals(_boundRoles, roles)) return;

    _boundUserId = userId;
    _boundRoles = Set<HDCInternalRole>.unmodifiable(roles);
    _bindingVersion += 1;
    _snapshot = null;
    _reviewQueue = const [];
    _recoveryReviewQueue = const [];
    _disputeQueue = const [];
    _disputeEvents = const [];
    _isLoading = false;
    _isSubmitting = false;
    _lastError = null;

    final bindingVersion = _bindingVersion;
    scheduleMicrotask(() {
      if (_disposed || bindingVersion != _bindingVersion) return;
      _announce();
    });
  }

  Future<void> refresh() async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed ||
        api == null ||
        userId == null ||
        _boundRoles.isEmpty ||
        _isLoading) {
      return;
    }

    final bindingVersion = _bindingVersion;
    _isLoading = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.get('/api/internal/dashboard');
      if (!_isCurrent(userId, bindingVersion)) return;
      final snapshot = HDCInternalDashboardSnapshot.fromJson(response);
      if (snapshot.userId != userId) {
        throw const HdcWorkflowException(
          code: 'invalid_server_response',
          message: 'HDC returned an invalid private workspace response.',
        );
      }
      _snapshot = snapshot;
    } on Object catch (error) {
      if (_isCurrent(userId, bindingVersion)) _lastError = error;
    } finally {
      if (_isCurrent(userId, bindingVersion)) {
        _isLoading = false;
        _announce();
      }
    }
  }

  Future<void> loadReviewQueue() async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed ||
        api == null ||
        userId == null ||
        !permissions.canApprovePlatformRoles ||
        _isLoading) {
      return;
    }

    final bindingVersion = _bindingVersion;
    _isLoading = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.get('/api/internal/role-applications');
      if (!_isCurrent(userId, bindingVersion)) return;
      _reviewQueue = List<PlatformRoleApplication>.unmodifiable(
        _objectList(response['applications'])
            .map(PlatformRoleApplication.fromJson),
      );
      _setPendingReviewCount(_reviewQueue.length);
    } on Object catch (error) {
      if (_isCurrent(userId, bindingVersion)) _lastError = error;
    } finally {
      if (_isCurrent(userId, bindingVersion)) {
        _isLoading = false;
        _announce();
      }
    }
  }

  Future<void> reviewApplication(
    PlatformRoleApplication application, {
    required String decision,
    String note = '',
  }) async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed ||
        api == null ||
        userId == null ||
        !permissions.canApprovePlatformRoles) {
      throw const HdcWorkflowException(
        code: 'internal_role_required',
        message: 'Approval permission is required for this action.',
      );
    }

    final bindingVersion = _bindingVersion;
    _isSubmitting = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.put(
        '/api/internal/role-applications/'
        '${Uri.encodeComponent(application.id)}',
        body: {
          'decision': decision,
          'note': note.trim(),
        },
      );
      if (!_isCurrent(userId, bindingVersion)) return;
      final reviewed = PlatformRoleApplication.fromJson(
        _requiredObject(response, 'application'),
      );
      _reviewQueue = List<PlatformRoleApplication>.unmodifiable(
        _reviewQueue.where((item) => item.id != reviewed.id),
      );
      _setPendingReviewCount(_reviewQueue.length);
    } on Object catch (error) {
      if (_isCurrent(userId, bindingVersion)) _lastError = error;
      rethrow;
    } finally {
      if (_isCurrent(userId, bindingVersion)) {
        _isSubmitting = false;
        _announce();
      }
    }
  }

  Future<void> loadRecoveryReviewQueue() async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed ||
        api == null ||
        userId == null ||
        !permissions.canReviewAccountRecovery ||
        _isLoading) {
      return;
    }

    final bindingVersion = _bindingVersion;
    _isLoading = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.get('/api/internal/account-recovery');
      if (!_isCurrent(userId, bindingVersion)) return;
      _recoveryReviewQueue = List<AccountRecoveryReviewRequest>.unmodifiable(
        _objectList(response['requests'])
            .map(AccountRecoveryReviewRequest.fromJson),
      );
      _setPendingRecoveryReviewCount(_recoveryReviewQueue.length);
    } on Object catch (error) {
      if (_isCurrent(userId, bindingVersion)) _lastError = error;
    } finally {
      if (_isCurrent(userId, bindingVersion)) {
        _isLoading = false;
        _announce();
      }
    }
  }

  Future<AccountRecoveryReviewResult> reviewRecoveryRequest(
    AccountRecoveryReviewRequest request, {
    required bool approve,
    String note = '',
  }) async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed ||
        api == null ||
        userId == null ||
        !permissions.canReviewAccountRecovery) {
      throw const HdcWorkflowException(
        code: 'internal_role_required',
        message: 'Private recovery-review permission is required.',
      );
    }

    final bindingVersion = _bindingVersion;
    _isSubmitting = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.put(
        '/api/internal/account-recovery/${Uri.encodeComponent(request.id)}',
        body: {
          'decision': approve ? 'approved' : 'rejected',
          'note': note.trim(),
        },
      );
      final result = AccountRecoveryReviewResult.fromJson(response);
      if (_isCurrent(userId, bindingVersion)) {
        _recoveryReviewQueue = List<AccountRecoveryReviewRequest>.unmodifiable(
          _recoveryReviewQueue.where((item) => item.id != result.request.id),
        );
        _setPendingRecoveryReviewCount(_recoveryReviewQueue.length);
      }
      return result;
    } on Object catch (error) {
      if (_isCurrent(userId, bindingVersion)) _lastError = error;
      rethrow;
    } finally {
      if (_isCurrent(userId, bindingVersion)) {
        _isSubmitting = false;
        _announce();
      }
    }
  }

  Future<void> loadDisputeQueue() async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed ||
        api == null ||
        userId == null ||
        !permissions.canApprovePlatformRoles ||
        _isLoading) {
      return;
    }
    final bindingVersion = _bindingVersion;
    _isLoading = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.get('/api/internal/disputes');
      if (!_isCurrent(userId, bindingVersion)) return;
      _disputeQueue = List<HdcServiceDispute>.unmodifiable(
        _objectList(response['disputes']).map(HdcServiceDispute.fromJson),
      );
      _disputeEvents = List<HdcDisputeEvent>.unmodifiable(
        _objectList(response['events']).map(HdcDisputeEvent.fromJson),
      );
      _setPendingDisputeCount(
        _disputeQueue.where((item) => item.isActive).length,
      );
    } on Object catch (error) {
      if (_isCurrent(userId, bindingVersion)) _lastError = error;
    } finally {
      if (_isCurrent(userId, bindingVersion)) {
        _isLoading = false;
        _announce();
      }
    }
  }

  Future<void> resolveDispute(
    HdcServiceDispute dispute, {
    required String outcome,
    required String note,
  }) async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed ||
        api == null ||
        userId == null ||
        !permissions.canApprovePlatformRoles) {
      throw const HdcWorkflowException(
        code: 'dispute_resolution_forbidden',
        message: 'Owner or Super Admin access is required.',
      );
    }
    final bindingVersion = _bindingVersion;
    _isSubmitting = true;
    _lastError = null;
    _announce();
    try {
      await api.put(
        '/api/internal/disputes/${Uri.encodeComponent(dispute.id)}',
        body: {'outcome': outcome, 'note': note.trim()},
      );
      if (!_isCurrent(userId, bindingVersion)) return;
      await loadDisputeQueue();
    } on Object catch (error) {
      if (_isCurrent(userId, bindingVersion)) _lastError = error;
      rethrow;
    } finally {
      if (_isCurrent(userId, bindingVersion)) {
        _isSubmitting = false;
        _announce();
      }
    }
  }

  void _setPendingReviewCount(int value) {
    final current = _snapshot;
    if (current != null) {
      _snapshot = current.withStatistic('pendingRoleApplications', value);
    }
  }

  void _setPendingRecoveryReviewCount(int value) {
    final current = _snapshot;
    if (current != null) {
      _snapshot = current.withStatistic('pendingRecoveryReviews', value);
    }
  }

  void _setPendingDisputeCount(int value) {
    final current = _snapshot;
    if (current != null) {
      _snapshot = current.withStatistic('pendingDisputes', value);
    }
  }

  bool _isCurrent(String userId, int bindingVersion) =>
      !_disposed &&
      _boundUserId == userId &&
      _bindingVersion == bindingVersion;

  void _announce() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) {
    throw const HdcWorkflowException(
      code: 'invalid_server_response',
      message: 'HDC returned an invalid private workspace response.',
    );
  }
  return value.map((item) {
    if (item is! Map) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned an invalid private workspace response.',
      );
    }
    return item.map((key, value) => MapEntry('$key', value));
  }).toList(growable: false);
}

Map<String, dynamic> _requiredObject(
  Map<String, dynamic> response,
  String key,
) {
  final value = response[key];
  if (value is! Map) {
    throw const HdcWorkflowException(
      code: 'invalid_server_response',
      message: 'HDC returned an invalid private workspace response.',
    );
  }
  return value.map((key, value) => MapEntry('$key', value));
}
