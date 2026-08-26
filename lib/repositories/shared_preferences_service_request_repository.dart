import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_request.dart';
import 'service_request_repository.dart';

class SharedPreferencesServiceRequestRepository
    implements ServiceRequestRepository {
  static const _storageKey = 'hdc_service_requests_v1';

  final List<ServiceRequest> _requests = [];
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    await _load();
    _initialized = true;
  }

  @override
  Future<void> refresh() async {
    await _load();
    _initialized = true;
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);

    _requests.clear();
    if (stored != null && stored.trim().isNotEmpty) {
      final decoded = jsonDecode(stored);
      if (decoded is List) {
        _requests.addAll(
          decoded.whereType<Map>().map(
            (item) => ServiceRequest.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
      }
    }
  }

  @override
  List<ServiceRequest> getAll() {
    final requests = List<ServiceRequest>.from(_requests);
    requests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return requests;
  }

  @override
  ServiceRequest? byId(String id) {
    for (final request in _requests) {
      if (request.id == id) return request;
    }
    return null;
  }

  @override
  Future<void> create(ServiceRequest request) async {
    _requests.add(request);
    await _persist();
  }

  @override
  Future<void> update(ServiceRequest request) async {
    final index = _requests.indexWhere((item) => item.id == request.id);
    if (index == -1) {
      throw StateError('Service request ${request.id} was not found.');
    }
    _requests[index] = request;
    await _persist();
  }

  @override
  Future<void> delete(String id) async {
    _requests.removeWhere((request) => request.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _requests.map((request) => request.toJson()).toList(),
    );
    final saved = await preferences.setString(_storageKey, encoded);
    if (!saved) {
      throw StateError('Service requests could not be saved locally.');
    }
  }
}
