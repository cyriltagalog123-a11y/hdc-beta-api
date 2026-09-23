import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';
import '../models/hdc_notification.dart';

class HdcNotificationCenterProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;

  String? _boundUserId;
  List<HdcNotification> _notifications = const [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _disposed = false;
  Object? _lastError;
  int _bindingVersion = 0;
  int _readVersion = 0;

  HdcNotificationCenterProvider({this.client});

  List<HdcNotification> get notifications =>
      List<HdcNotification>.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get backendAvailable => client != null;
  Object? get lastError => _lastError;

  void bindUser(String? userId) {
    if (_disposed || _boundUserId == userId) return;
    _boundUserId = userId;
    _bindingVersion += 1;
    _readVersion += 1;
    _isLoading = false;
    _notifications = const [];
    _unreadCount = 0;
    _lastError = null;
    final version = _bindingVersion;
    scheduleMicrotask(() {
      if (_disposed || version != _bindingVersion) return;
      _announce();
      if (userId != null && client != null) unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed || api == null || userId == null || _isLoading) return;
    final version = _bindingVersion;
    final readVersion = ++_readVersion;
    _isLoading = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.get('/api/notifications');
      if (!_isCurrent(userId, version) || readVersion != _readVersion) return;
      final values = response['notifications'];
      if (values is! List) {
        throw const HdcWorkflowException(
          code: 'invalid_server_response',
          message: 'HDC returned invalid notification data.',
        );
      }
      _notifications = List<HdcNotification>.unmodifiable(
        values.whereType<Map>().map((item) {
          return HdcNotification.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          );
        }),
      );
      _unreadCount = response['unreadCount'] is num
          ? (response['unreadCount'] as num).toInt()
          : _notifications.where((item) => item.isUnread).length;
      _lastError = null;
    } on Object catch (error) {
      if (_isCurrent(userId, version) && readVersion == _readVersion) {
        _lastError = error;
      }
    } finally {
      if (_isCurrent(userId, version) && readVersion == _readVersion) {
        _isLoading = false;
        _announce();
      }
    }
  }

  Future<void> markRead(String notificationId) async {
    final api = _requireClient();
    final userId = _requireUser();
    final version = _bindingVersion;
    final response = await api.put(
      '/api/notifications/${Uri.encodeComponent(notificationId)}/read',
      body: const {},
    );
    if (!_isCurrent(userId, version)) return;
    final value = response['notification'];
    if (value is! Map || value['id'] != notificationId) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned a different notification record.',
      );
    }
    final updated = HdcNotification.fromJson(
      value.map((key, value) => MapEntry('$key', value)),
    );
    final wasUnread = _notifications.any(
      (item) => item.id == notificationId && item.isUnread,
    );
    _notifications = List<HdcNotification>.unmodifiable(
      _notifications.map((item) => item.id == updated.id ? updated : item),
    );
    if (wasUnread && !updated.isUnread && _unreadCount > 0) _unreadCount -= 1;
    _refreshAfterWrite();
    _announce();
  }

  Future<void> markAllRead() async {
    final api = _requireClient();
    final userId = _requireUser();
    final version = _bindingVersion;
    await api.put('/api/notifications/read-all', body: const {});
    if (!_isCurrent(userId, version)) return;
    final now = DateTime.now().toUtc();
    _notifications = List<HdcNotification>.unmodifiable(
      _notifications.map((item) => item.isUnread ? item.copyWith(readAt: now) : item),
    );
    _unreadCount = 0;
    _refreshAfterWrite();
    _announce();
  }

  void _refreshAfterWrite() {
    // A read started before the write cannot undo the saved read state.
    _readVersion += 1;
    _isLoading = false;
    unawaited(refresh());
  }

  HdcWorkflowApiClient _requireClient() {
    final api = client;
    if (api == null) {
      throw StateError('The HDC notification service is unavailable.');
    }
    return api;
  }

  String _requireUser() {
    final userId = _boundUserId;
    if (_disposed || userId == null) {
      throw const HdcWorkflowException(
        code: 'authentication_required',
        message: 'Sign in to view notifications.',
      );
    }
    return userId;
  }

  bool _isCurrent(String userId, int version) =>
      !_disposed && _boundUserId == userId && _bindingVersion == version;

  void _announce() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
