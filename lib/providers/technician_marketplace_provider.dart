import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_request.dart';

enum TechnicianMarketplaceSort { nearbyArea, newest, urgency }

extension TechnicianMarketplaceSortDetails on TechnicianMarketplaceSort {
  String get label {
    switch (this) {
      case TechnicianMarketplaceSort.nearbyArea:
        return 'Nearby area';
      case TechnicianMarketplaceSort.newest:
        return 'Newest';
      case TechnicianMarketplaceSort.urgency:
        return 'Urgency';
    }
  }
}

class TechnicianMarketplaceProvider extends ChangeNotifier {
  static const _savedKeyPrefix = 'hdc_technician_saved_request_ids_v2';

  final Set<String> _savedRequestIds = <String>{};

  String? _boundUserId;
  int _bindingVersion = 0;
  String _query = '';
  String? _category;
  ServiceRequestUrgency? _urgency;
  TechnicianMarketplaceSort _sort = TechnicianMarketplaceSort.nearbyArea;
  bool _savedOnly = false;
  bool _isLoading = false;
  bool _disposed = false;

  String get query => _query;
  String? get category => _category;
  ServiceRequestUrgency? get urgency => _urgency;
  TechnicianMarketplaceSort get sort => _sort;
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
    _sort = TechnicianMarketplaceSort.nearbyArea;
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
    await preferences.setStringList(_savedKey(userId), savedRequestIds);
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

  void setSort(TechnicianMarketplaceSort value) {
    if (_sort == value) return;
    _sort = value;
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

  List<ServiceRequest> applyFilters(
    List<ServiceRequest> source, {
    String? technicianId,
    String technicianLocation = '',
  }) {
    final filtered = source
        .where((request) {
          if (!request.status.acceptsProposals) return false;
          if (technicianId != null && request.customerId == technicianId) {
            return false;
          }
          if (_savedOnly && !isSaved(request.id)) return false;
          if (_category != null && request.categoryName != _category)
            return false;
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
        })
        .toList(growable: false);

    filtered.sort(
      (a, b) => _compareRequests(a, b, technicianLocation: technicianLocation),
    );
    return filtered;
  }

  int _compareRequests(
    ServiceRequest a,
    ServiceRequest b, {
    required String technicianLocation,
  }) {
    switch (_sort) {
      case TechnicianMarketplaceSort.nearbyArea:
        final areaComparison = _areaMatchRank(
          b.location,
          technicianLocation,
        ).compareTo(_areaMatchRank(a.location, technicianLocation));
        if (areaComparison != 0) return areaComparison;
        final urgencyComparison = _compareUrgency(a, b);
        if (urgencyComparison != 0) return urgencyComparison;
        return b.createdAt.compareTo(a.createdAt);
      case TechnicianMarketplaceSort.newest:
        return b.createdAt.compareTo(a.createdAt);
      case TechnicianMarketplaceSort.urgency:
        final urgencyComparison = _compareUrgency(a, b);
        if (urgencyComparison != 0) return urgencyComparison;
        return b.createdAt.compareTo(a.createdAt);
    }
  }

  int _compareUrgency(ServiceRequest a, ServiceRequest b) =>
      _urgencyRank(b.urgency).compareTo(_urgencyRank(a.urgency));

  int _areaMatchRank(String requestLocation, String technicianLocation) {
    final request = _normalizeLocation(requestLocation);
    final technician = _normalizeLocation(technicianLocation);
    if (request.isEmpty || technician.isEmpty) return 0;
    if (request == technician) return 3;
    if (request.contains(technician) || technician.contains(request)) return 2;

    final requestTokens = _meaningfulLocationTokens(request);
    final technicianTokens = _meaningfulLocationTokens(technician);
    return requestTokens.intersection(technicianTokens).isEmpty ? 0 : 1;
  }

  String _normalizeLocation(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Set<String> _meaningfulLocationTokens(String value) {
    const generic = <String>{
      'barangay',
      'brgy',
      'city',
      'municipality',
      'province',
      'philippines',
    };
    return value
        .split(' ')
        .where((token) => token.length > 2 && !generic.contains(token))
        .toSet();
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
