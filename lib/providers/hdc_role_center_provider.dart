import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';
import '../models/account_identity.dart';
import '../models/platform_role_application.dart';

class HdcRoleCenterProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;

  String? _boundUserId;
  Set<HDCPlatformRole> _platformRoles = const <HDCPlatformRole>{};
  List<PlatformRoleApplication> _applications = const [];
  List<RoleCenterNotification> _notifications = const [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  Object? _lastError;
  int _bindingVersion = 0;
  bool _disposed = false;

  HdcRoleCenterProvider({this.client});

  Set<HDCPlatformRole> get platformRoles =>
      Set<HDCPlatformRole>.unmodifiable(_platformRoles);
  List<PlatformRoleApplication> get applications =>
      List<PlatformRoleApplication>.unmodifiable(_applications);
  List<RoleCenterNotification> get notifications =>
      List<RoleCenterNotification>.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get backendAvailable => client != null;
  Object? get lastError => _lastError;

  void bindIdentity(AccountIdentity? identity) {
    if (_disposed) return;
    final userId = identity?.id;
    final sameIdentity = _boundUserId == userId &&
        setEquals(
          _platformRoles,
          identity?.platformRoles ?? const <HDCPlatformRole>{},
        );
    if (sameIdentity) return;

    final accountChanged = _boundUserId != userId;
    _boundUserId = userId;
    _platformRoles = Set<HDCPlatformRole>.unmodifiable(
      identity?.platformRoles ?? const <HDCPlatformRole>{},
    );

    if (!accountChanged) {
      final bindingVersion = _bindingVersion;
      scheduleMicrotask(() {
        if (_disposed || bindingVersion != _bindingVersion) return;
        _announce();
      });
      return;
    }

    _bindingVersion += 1;
    _applications = const [];
    _notifications = const [];
    _isLoading = false;
    _isSubmitting = false;
    _lastError = null;
    final bindingVersion = _bindingVersion;
    scheduleMicrotask(() {
      if (_disposed || bindingVersion != _bindingVersion) return;
      _announce();
      if (userId != null && client != null) unawaited(refresh());
    });
  }

  PlatformRoleApplication? latestApplicationFor(HDCPlatformRole role) {
    for (final application in _applications) {
      if (application.role == role) return application;
    }
    return null;
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
      final response = await api.get('/api/roles/overview');
      if (!_isCurrent(userId, bindingVersion)) return;

      _platformRoles = Set<HDCPlatformRole>.unmodifiable(
        _parsePlatformRoles(response['platformRoles']),
      );
      _applications = List<PlatformRoleApplication>.unmodifiable(
        _objectList(response['applications'])
            .map(PlatformRoleApplication.fromJson),
      );
      _notifications = List<RoleCenterNotification>.unmodifiable(
        _objectList(response['notifications'])
            .map(RoleCenterNotification.fromJson),
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

  Future<void> applyForRole(
    HDCPlatformRole role, {
    required Map<String, Object?> answers,
    String note = '',
  }) async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed || api == null || userId == null) {
      throw const HdcWorkflowException(
        code: 'role_backend_unavailable',
        message: 'HDC role applications require the HDC API.',
      );
    }
    if (!role.requiresApproval || _platformRoles.contains(role)) {
      throw const HdcWorkflowException(
        code: 'invalid_platform_role',
        message: 'That HDC platform role cannot be requested.',
      );
    }

    final bindingVersion = _bindingVersion;
    _isSubmitting = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.post(
        '/api/role-applications',
        body: {
          'role': role.code,
          'answers': answers,
          'note': note.trim(),
        },
      );
      if (!_isCurrent(userId, bindingVersion)) return;
      final application = PlatformRoleApplication.fromJson(
        _requiredObject(response, 'application'),
      );
      _upsertApplication(application);
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

  void _upsertApplication(PlatformRoleApplication application) {
    final values = [..._applications];
    final index = values.indexWhere((item) => item.id == application.id);
    if (index == -1) {
      values.insert(0, application);
    } else {
      values[index] = application;
    }
    _applications = List<PlatformRoleApplication>.unmodifiable(values);
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

Set<HDCPlatformRole> _parsePlatformRoles(Object? value) {
  final roles = <HDCPlatformRole>{};
  if (value is List) {
    for (final item in value) {
      final role = parseHDCPlatformRole(item);
      if (role != null) roles.add(role);
    }
  }
  return roles;
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) {
    throw const HdcWorkflowException(
      code: 'invalid_server_response',
      message: 'HDC returned an invalid role response.',
    );
  }
  return value.map((item) {
    if (item is! Map) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned an invalid role response.',
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
      message: 'HDC returned an invalid role response.',
    );
  }
  return value.map((key, value) => MapEntry('$key', value));
}
