import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';
import '../models/account_identity.dart';
import '../models/service_request.dart';
import '../models/technician_directory_entry.dart';

class TechnicianDiscoveryProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;

  String? _boundUserId;
  bool _canBrowseOpportunities = false;
  int _bindingVersion = 0;
  bool _disposed = false;

  List<TechnicianDirectoryEntry> _technicians = const [];
  List<ServiceRequest> _opportunities = const [];
  bool _isLoadingDirectory = false;
  bool _isLoadingOpportunities = false;
  Object? _directoryError;
  Object? _opportunitiesError;
  DateTime? _directoryUpdatedAt;
  DateTime? _opportunitiesUpdatedAt;
  Future<void>? _directoryRefresh;
  Future<void>? _opportunitiesRefresh;

  TechnicianDiscoveryProvider({this.client});

  List<TechnicianDirectoryEntry> get technicians =>
      List<TechnicianDirectoryEntry>.unmodifiable(_technicians);
  List<ServiceRequest> get opportunities =>
      List<ServiceRequest>.unmodifiable(_opportunities);
  bool get isLoadingDirectory => _isLoadingDirectory;
  bool get isLoadingOpportunities => _isLoadingOpportunities;
  Object? get directoryError => _directoryError;
  Object? get opportunitiesError => _opportunitiesError;
  DateTime? get directoryUpdatedAt => _directoryUpdatedAt;
  DateTime? get opportunitiesUpdatedAt => _opportunitiesUpdatedAt;
  bool get backendAvailable => client != null;

  void bindIdentity(AccountIdentity? identity) {
    if (_disposed) return;
    final userId = identity?.id;
    final canBrowse =
        identity?.hasPlatformRole(HDCPlatformRole.technician) == true;
    if (_boundUserId == userId && _canBrowseOpportunities == canBrowse) return;

    _boundUserId = userId;
    _canBrowseOpportunities = canBrowse;
    _bindingVersion += 1;
    _technicians = const [];
    _opportunities = const [];
    _directoryError = null;
    _opportunitiesError = null;
    _directoryUpdatedAt = null;
    _opportunitiesUpdatedAt = null;
    _isLoadingDirectory = false;
    _isLoadingOpportunities = false;
    // A request started for the previous account cannot be cancelled, but it
    // must not prevent the newly bound account from starting its own refresh.
    _directoryRefresh = null;
    _opportunitiesRefresh = null;
    final bindingVersion = _bindingVersion;

    scheduleMicrotask(() {
      if (_disposed || bindingVersion != _bindingVersion) return;
      notifyListeners();
      if (userId == null || client == null) return;
      unawaited(refreshDirectory());
      if (canBrowse) unawaited(refreshOpportunities());
    });
  }

  Future<void> refreshDirectory() {
    final active = _directoryRefresh;
    if (active != null) return active;
    final pending = _loadDirectory();
    _directoryRefresh = pending;
    return pending.whenComplete(() {
      if (identical(_directoryRefresh, pending)) _directoryRefresh = null;
    });
  }

  Future<void> _loadDirectory() async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed || api == null || userId == null) return;
    final bindingVersion = _bindingVersion;
    _isLoadingDirectory = true;
    _directoryError = null;
    notifyListeners();

    try {
      final response = await api.get('/api/discovery/technicians');
      if (!_isCurrent(userId, bindingVersion)) return;
      final values = _objectList(response['technicians'])
          .map(TechnicianDirectoryEntry.fromJson)
          .toList(growable: false);
      _technicians = List<TechnicianDirectoryEntry>.unmodifiable(values);
      _directoryUpdatedAt = _responseTime(response['updatedAt']);
    } on Object catch (error) {
      if (_isCurrent(userId, bindingVersion)) _directoryError = error;
    } finally {
      if (_isCurrent(userId, bindingVersion)) {
        _isLoadingDirectory = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshOpportunities() {
    final active = _opportunitiesRefresh;
    if (active != null) return active;
    final pending = _loadOpportunities();
    _opportunitiesRefresh = pending;
    return pending.whenComplete(() {
      if (identical(_opportunitiesRefresh, pending)) {
        _opportunitiesRefresh = null;
      }
    });
  }

  Future<void> _loadOpportunities() async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed ||
        api == null ||
        userId == null ||
        !_canBrowseOpportunities) {
      return;
    }
    final bindingVersion = _bindingVersion;
    _isLoadingOpportunities = true;
    _opportunitiesError = null;
    notifyListeners();

    try {
      final response = await api.get('/api/discovery/opportunities');
      if (!_isCurrent(userId, bindingVersion)) return;
      final values = _objectList(response['serviceRequests'])
          .map(ServiceRequest.fromJson)
          .toList(growable: false);
      _opportunities = List<ServiceRequest>.unmodifiable(values);
      _opportunitiesUpdatedAt = _responseTime(response['updatedAt']);
    } on Object catch (error) {
      if (_isCurrent(userId, bindingVersion)) _opportunitiesError = error;
    } finally {
      if (_isCurrent(userId, bindingVersion)) {
        _isLoadingOpportunities = false;
        notifyListeners();
      }
    }
  }

  List<TechnicianDirectoryEntry> searchTechnicians({
    String query = '',
    String serviceArea = '',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final values = _technicians
        .where((technician) {
          return normalizedQuery.isEmpty ||
              technician.searchableText.contains(normalizedQuery);
        })
        .toList(growable: false);

    values.sort((a, b) {
      final area = areaMatchRank(
        b.location,
        serviceArea,
      ).compareTo(areaMatchRank(a.location, serviceArea));
      if (area != 0) return area;
      return a.publicName.toLowerCase().compareTo(b.publicName.toLowerCase());
    });
    return values;
  }

  @visibleForTesting
  static int areaMatchRank(String candidateLocation, String serviceArea) {
    final candidate = _normalizeLocation(candidateLocation);
    final requested = _normalizeLocation(serviceArea);
    if (candidate.isEmpty || requested.isEmpty) return 0;
    if (candidate == requested) return 3;
    if (candidate.contains(requested) || requested.contains(candidate)) {
      return 2;
    }
    final candidateTokens = _meaningfulTokens(candidate);
    final requestedTokens = _meaningfulTokens(requested);
    return candidateTokens.intersection(requestedTokens).isEmpty ? 0 : 1;
  }

  bool _isCurrent(String userId, int bindingVersion) =>
      !_disposed && _boundUserId == userId && _bindingVersion == bindingVersion;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry('$key', value)))
      .toList(growable: false);
}

DateTime _responseTime(Object? value) =>
    value is String && DateTime.tryParse(value) != null
    ? DateTime.parse(value).toLocal()
    : DateTime.now();

String _normalizeLocation(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

Set<String> _meaningfulTokens(String value) {
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
