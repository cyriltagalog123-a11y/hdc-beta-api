import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/hdc_api_workflow_repositories.dart';

class HdcWorkflowSyncProvider extends ChangeNotifier {
  final HdcApiWorkflowStore store;

  String? _boundUserId;
  bool _isSyncing = false;
  bool _refreshRequested = false;
  Object? _lastError;
  int _generation = 0;
  int _bindingVersion = 0;
  bool _disposed = false;

  HdcWorkflowSyncProvider({required this.store});

  bool get isSyncing => _isSyncing;
  Object? get lastError => _lastError;
  int get generation => _generation;

  void bindUser(String? userId) {
    if (_disposed || _boundUserId == userId) return;
    _boundUserId = userId;
    _bindingVersion += 1;
    store.bindUser(userId, announce: false);
    _lastError = null;
    _generation += 1;
    final bindingVersion = _bindingVersion;
    scheduleMicrotask(() {
      if (_disposed || _bindingVersion != bindingVersion) return;
      store.announceCacheChange();
      notifyListeners();
      if (userId != null && _boundUserId == userId) {
        unawaited(refresh());
      }
    });
  }

  Future<void> refresh() async {
    if (_disposed || _boundUserId == null) return;
    if (_isSyncing) {
      _refreshRequested = true;
      return;
    }

    do {
      _refreshRequested = false;
      final userId = _boundUserId;
      final bindingVersion = _bindingVersion;
      if (userId == null) return;

      _isSyncing = true;
      if (!_disposed) notifyListeners();
      try {
        await store.refresh();
        if (_boundUserId == userId &&
            _bindingVersion == bindingVersion) {
          _lastError = null;
          _generation += 1;
        }
      } on Object catch (error) {
        if (_boundUserId == userId &&
            _bindingVersion == bindingVersion) {
          _lastError = error;
        }
      } finally {
        _isSyncing = false;
        if (!_disposed) notifyListeners();
      }
    } while (!_disposed && _refreshRequested && _boundUserId != null);
  }

  @override
  void dispose() {
    _disposed = true;
    store.dispose();
    super.dispose();
  }
}
