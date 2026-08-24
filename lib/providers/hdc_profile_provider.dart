import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';
import '../models/account_identity.dart';
import '../models/hdc_profile.dart';

class HdcProfileProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;

  String? _boundUserId;
  Set<HDCPlatformRole> _boundRoles = const <HDCPlatformRole>{};
  HDCMemberProfile? _memberProfile;
  Map<HDCPlatformRole, HDCPlatformRoleProfile> _roleProfiles = const {};
  HDCPlatformRole? _selectedRole;
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _lastError;
  int _bindingVersion = 0;
  bool _disposed = false;

  HdcProfileProvider({this.client});

  HDCMemberProfile? get memberProfile => _memberProfile;
  Map<HDCPlatformRole, HDCPlatformRoleProfile> get roleProfiles =>
      Map<HDCPlatformRole, HDCPlatformRoleProfile>.unmodifiable(_roleProfiles);
  HDCPlatformRole? get selectedRole => _selectedRole;
  Set<HDCPlatformRole> get activeRoles =>
      Set<HDCPlatformRole>.unmodifiable(_boundRoles);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get backendAvailable => client != null;
  Object? get lastError => _lastError;

  HDCPlatformRoleProfile? profileFor(HDCPlatformRole role) =>
      _roleProfiles[role];

  void bindIdentity(AccountIdentity? identity) {
    if (_disposed) return;
    final userId = identity?.id;
    final roles = identity?.platformRoles ?? const <HDCPlatformRole>{};
    if (_boundUserId == userId && setEquals(_boundRoles, roles)) return;

    _bindingVersion += 1;
    _boundUserId = userId;
    _boundRoles = Set<HDCPlatformRole>.unmodifiable(roles);
    _roleProfiles = const {};
    _lastError = null;
    _isLoading = false;
    _isSaving = false;
    _selectedRole = _defaultRole(_boundRoles);
    _memberProfile = identity == null ? null : _seedMemberProfile(identity);

    final bindingVersion = _bindingVersion;
    scheduleMicrotask(() {
      if (_disposed || bindingVersion != _bindingVersion) return;
      _announce();
      if (userId != null && client != null) unawaited(refresh());
    });
  }

  void selectRole(HDCPlatformRole role) {
    if (_disposed || !_boundRoles.contains(role) || _selectedRole == role) {
      return;
    }
    _selectedRole = role;
    _announce();
  }

  Future<void> refresh() async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed || api == null || userId == null || _isLoading) return;

    final bindingVersion = _bindingVersion;
    _isLoading = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.get('/api/profiles');
      if (!_isCurrent(userId, bindingVersion)) return;
      final bundle = HDCProfileBundle.fromJson(response);
      _memberProfile = bundle.memberProfile;
      _roleProfiles = bundle.roleProfiles;
      _boundRoles = Set<HDCPlatformRole>.unmodifiable(
        bundle.roleProfiles.keys,
      );
      if (_selectedRole == null || !_roleProfiles.containsKey(_selectedRole)) {
        _selectedRole = _defaultRole(_roleProfiles.keys.toSet());
      }
    } on Object catch (error) {
      if (_isCurrent(userId, bindingVersion)) _lastError = error;
    } finally {
      if (_isCurrent(userId, bindingVersion)) {
        _isLoading = false;
        _announce();
      }
    }
  }

  Future<HDCMemberProfile> saveMember({
    required String displayName,
    required String bio,
    required String location,
    required String avatarUrl,
    required String contactPreference,
  }) async {
    final response = await _save(
      '/api/profiles/member',
      body: {
        'displayName': displayName.trim(),
        'bio': bio.trim(),
        'location': location.trim(),
        'avatarUrl': avatarUrl.trim(),
        'contactPreference': contactPreference,
      },
    );
    final value = _requiredObject(response, 'memberProfile');
    final member = HDCMemberProfile.fromJson(value);
    _memberProfile = member;
    _announce();
    return member;
  }

  Future<HDCPlatformRoleProfile> saveRoleProfile(
    HDCPlatformRole role, {
    required Map<String, Object?> body,
  }) async {
    if (!_boundRoles.contains(role)) {
      throw const HdcWorkflowException(
        code: 'profile_role_inactive',
        message: 'Activate this platform role before editing its profile.',
      );
    }
    final response = await _save(
      '/api/profiles/${Uri.encodeComponent(role.code)}',
      body: body,
    );
    final value = _requiredObject(response, 'roleProfile');
    final profile = HDCPlatformRoleProfile.fromJson(value);
    _roleProfiles = Map<HDCPlatformRole, HDCPlatformRoleProfile>.unmodifiable({
      ..._roleProfiles,
      role: profile,
    });
    _selectedRole = role;
    _announce();
    return profile;
  }

  Future<Map<String, dynamic>> _save(
    String path, {
    required Map<String, Object?> body,
  }) async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed || api == null || userId == null) {
      throw const HdcWorkflowException(
        code: 'profile_backend_unavailable',
        message: 'HDC profiles require the authenticated HDC API.',
      );
    }

    final bindingVersion = _bindingVersion;
    _isSaving = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.put(path, body: body);
      if (!_isCurrent(userId, bindingVersion)) {
        throw const HdcWorkflowException(
          code: 'profile_request_stale',
          message: 'The signed-in HDC account changed while saving.',
        );
      }
      return response;
    } on Object catch (error) {
      if (_isCurrent(userId, bindingVersion)) _lastError = error;
      rethrow;
    } finally {
      if (_isCurrent(userId, bindingVersion)) {
        _isSaving = false;
        _announce();
      }
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

HDCPlatformRole? _defaultRole(Set<HDCPlatformRole> roles) {
  if (roles.contains(HDCPlatformRole.customer)) return HDCPlatformRole.customer;
  for (final role in HDCPlatformRole.values) {
    if (roles.contains(role)) return role;
  }
  return null;
}

HDCMemberProfile _seedMemberProfile(AccountIdentity identity) {
  return HDCMemberProfile(
    userId: identity.id,
    displayName: identity.displayName,
    email: identity.email ?? '',
    bio: '',
    location: '',
    avatarUrl: '',
    contactPreference: 'in_app',
    version: 1,
    createdAt: identity.createdAt,
    updatedAt: identity.updatedAt,
  );
}

Map<String, dynamic> _requiredObject(
  Map<String, dynamic> response,
  String key,
) {
  final value = response[key];
  if (value is! Map) {
    throw const HdcWorkflowException(
      code: 'invalid_server_response',
      message: 'HDC returned an invalid profile response.',
    );
  }
  return value.map((key, value) => MapEntry('$key', value));
}
