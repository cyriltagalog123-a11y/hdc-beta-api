import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_request.dart';

class TechnicianMarketplaceProvider extends ChangeNotifier {
  static const _savedKeyPrefix = 'hdc_technician_saved_request_ids_v2';

  final Set<String> _savedRequestIds = <String>{};

  String? _boundUserId;
  int _bindingVersion = 0;
  String _query = '';
  String? _category;
  ServiceRequestUrgency? _urgency;
  bool _savedOnly = false;
  bool _isLoading = false;
  bool _disposed = false;

  String get query => _query;
  String? get category => _category;
  ServiceRequestUrgency? get urgency => _urgency;
  bool get savedOnly => _savedOnly;
  bool get isLoading => _isLoading;
  int get savedCount => _savedRequestIds.length;

  bool get hasActiveFilters =>
      _query.isNotEmpty || _category != null || _urgency != null || _savedOnly;

  void bindUser(String? userId) {
    if (_disposed || _boundUserId == userId) return;
    _boundUserId = userId;
    _bindingVersion += 1;
    _savedRequestIds.clear();
    _query = '';
    _category = null;
    _urgency = null;
    _savedOnly = false;
    _isLoading = userId != null;
    final bindingVersion = _bindingVersion;
    scheduleMicrotask(() {
      if (!_disposed && bindingVersion == _bindingVersion) notifyListeners();
    });
    if (userId != null) {
      unawaited(_loadSaved(userId, bindingVersion));
    }
  }

  Future<void> _loadSaved(String userId, int bindingVersion) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_disposed ||
          _boundUserId != userId ||
          _bindingVersion != bindingVersion) {
        return;
      }
      _savedRequestIds
        ..clear()
        ..addAll(
          preferences.getStringList(_savedKey(userId)) ?? const <String>[],
        );
    } finally {
      if (!_disposed &&
          _boundUserId == userId &&
          _bindingVersion == bindingVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  String _savedKey(String userId) => '$_savedKeyPrefix.$userId';

  bool isSaved(String requestId) => _savedRequestIds.contains(requestId);

  Future<void> toggleSaved(String requestId) async {
    final userId = _boundUserId;
    if (userId == null) {
      throw StateError('Sign in to save marketplace requests.');
    }
    if (!_savedRequestIds.add(requestId)) {
      _savedRequestIds.remove(requestId);
    }
    final savedRequestIds = _savedRequestIds.toList(growable: false);
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _savedKey(userId),
      savedRequestIds,
    );
  }

  void setQuery(String value) {
    final next = value.trim().toLowerCase();
    if (_query == next) return;
    _query = next;
    notifyListeners();
  }

  void setCategory(String? value) {
    if (_category == value) return;
    _category = value;
    notifyListeners();
  }

  void setUrgency(ServiceRequestUrgency? value) {
    if (_urgency == value) return;
    _urgency = value;
    notifyListeners();
  }

  void setSavedOnly(bool value) {
    if (_savedOnly == value) return;
    _savedOnly = value;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _category = null;
    _urgency = null;
    _savedOnly = false;
    notifyListeners();
  }

  List<ServiceRequest> applyFilters(List<ServiceRequest> source) {
    final filtered = source.where((request) {
      if (!request.status.acceptsProposals) return false;
      if (_savedOnly && !isSaved(request.id)) return false;
      if (_category != null && request.categoryName != _category) return false;
      if (_urgency != null && request.urgency != _urgency) return false;
      if (_query.isEmpty) return true;

      final haystack = <String>[
        request.title,
        request.categoryName,
        request.description,
        request.location,
        request.customerName,
      ].join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList(growable: false);

    filtered.sort((a, b) {
      final urgencyComparison =
          _urgencyRank(b.urgency).compareTo(_urgencyRank(a.urgency));
      if (urgencyComparison != 0) return urgencyComparison;
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }

  int _urgencyRank(ServiceRequestUrgency value) {
    switch (value) {
      case ServiceRequestUrgency.flexible:
        return 0;
      case ServiceRequestUrgency.normal:
        return 1;
      case ServiceRequestUrgency.urgent:
        return 2;
      case ServiceRequestUrgency.emergency:
        return 3;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
