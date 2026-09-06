import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';
import '../models/account_identity.dart';
import '../models/platform_role_admin_member.dart';

class PlatformRoleAdminProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;

  AccountIdentity? _identity;
  List<PlatformRoleAdminMember> _members = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _lastError;

  PlatformRoleAdminProvider({this.client});

  bool get backendAvailable => client != null;
  bool get hasAccess => _identity?.internalRoles.any(
        (role) =>
            role == HDCInternalRole.owner ||
            role == HDCInternalRole.superAdmin ||
            role == HDCInternalRole.admin,
      ) ?? false;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get lastError => _lastError;
  List<PlatformRoleAdminMember> get members => _members;

  void bindIdentity(AccountIdentity? identity) {
    if (_identity?.id == identity?.id &&
        setEquals(_identity?.internalRoles, identity?.internalRoles)) {
      return;
    }
    _identity = identity;
    _members = const [];
    _lastError = null;
    notifyListeners();
  }

  Future<void> search([String query = '']) async {
    final api = client;
    if (api == null) {
      _lastError = StateError('The HDC platform-role admin API is unavailable.');
      notifyListeners();
      return;
    }
    if (!hasAccess) {
      _lastError = StateError('This account cannot manage platform roles.');
      notifyListeners();
      return;
    }
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final encoded = Uri.encodeQueryComponent(query.trim());
      final response = await api.get(
        '/api/internal/platform-role-admin?q=$encoded',
      );
      final raw = response['members'];
      if (raw is! List) {
        throw const HdcWorkflowException(
          code: 'invalid_server_response',
          message: 'HDC returned an invalid member role list.',
        );
      }
      _members = List<PlatformRoleAdminMember>.unmodifiable(
        raw.whereType<Map>().map(
              (item) => PlatformRoleAdminMember.fromJson(
                item.map((key, value) => MapEntry('$key', value)),
              ),
            ),
      );
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changeRole({
    required PlatformRoleAdminMember member,
    required HDCPlatformRole role,
    required bool assign,
    required String reason,
  }) async {
    if (role == HDCPlatformRole.customer) {
      throw StateError('The baseline Customer role cannot be removed or reassigned here.');
    }
    final api = client;
    if (api == null || !hasAccess) {
      throw StateError('This account cannot manage platform roles.');
    }
    _isSaving = true;
    _lastError = null;
    notifyListeners();
    try {
      final response = await api.put(
        '/api/internal/platform-role-admin',
        body: {
          'targetUserId': member.id,
          'role': role.code,
          'action': assign ? 'assign' : 'revoke',
          'reason': reason.trim(),
        },
      );
      final rawMember = response['member'];
      if (rawMember is! Map) {
        throw const HdcWorkflowException(
          code: 'invalid_server_response',
          message: 'HDC returned an invalid role-change response.',
        );
      }
      final updated = PlatformRoleAdminMember.fromJson(
        rawMember.map((key, value) => MapEntry('$key', value)),
      );
      _members = List<PlatformRoleAdminMember>.unmodifiable(
        _members.map((item) => item.id == updated.id ? updated : item),
      );
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
