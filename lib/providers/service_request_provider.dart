import 'package:flutter/foundation.dart';

import '../models/service_request.dart';
import '../models/service_request_form_data.dart';
import '../repositories/service_request_repository.dart';

class ServiceRequestProvider extends ChangeNotifier {
  final ServiceRequestRepository repository;

  ServiceRequestProvider({required this.repository});

  bool _isLoading = true;
  bool _isSaving = false;
  Object? _lastError;
  Future<ServiceRequest>? _publishInFlight;
  String? _publishRequestId;
  Future<void>? _refreshInFlight;
  DateTime? _lastUpdated;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get lastError => _lastError;
  DateTime? get lastUpdated => _lastUpdated;

  List<ServiceRequest> get requests => repository.getAll();

  List<ServiceRequest> get activeRequests => requests
      .where((request) => request.status.isActive)
      .toList(growable: false);

  int get totalOffers =>
      requests.fold<int>(0, (total, request) => total + request.offerCount);

  ServiceRequest? byId(String id) => repository.byId(id);

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await repository.initialize();
      _lastError = null;
      _lastUpdated = DateTime.now();
    } on Object catch (error) {
      _lastError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() {
    final active = _refreshInFlight;
    if (active != null) return active;

    final pending = _refresh();
    _refreshInFlight = pending;
    return pending.whenComplete(() {
      if (identical(_refreshInFlight, pending)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<void> _refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      await repository.refresh();
      _lastError = null;
      _lastUpdated = DateTime.now();
    } on Object catch (error) {
      _lastError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ServiceRequest> publish({
    required ServiceRequestFormData form,
    required String customerId,
    required String customerName,
    required String requestId,
  }) {
    final active = _publishInFlight;
    if (active != null) {
      if (_publishRequestId == requestId) return active;
      return Future<ServiceRequest>.error(
        StateError('Another service request is already being published.'),
      );
    }

    final pending = _publish(
      form: form,
      customerId: customerId,
      customerName: customerName,
      requestId: requestId,
    );
    _publishInFlight = pending;
    _publishRequestId = requestId;
    return pending.whenComplete(() {
      if (identical(_publishInFlight, pending)) {
        _publishInFlight = null;
        _publishRequestId = null;
      }
    });
  }

  Future<ServiceRequest> _publish({
    required ServiceRequestFormData form,
    required String customerId,
    required String customerName,
    required String requestId,
  }) async {
    _setSaving(true);
    try {
      final now = DateTime.now();
      final request = ServiceRequest(
        id: requestId,
        customerId: customerId,
        customerName: customerName,
        title: form.title.trim(),
        categoryId: form.category.id,
        categoryName: form.category.name,
        description: form.description.trim(),
        location: form.location.trim(),
        preferredDate: form.preferredDate,
        preferredTime: form.preferredTime,
        urgency: form.urgency,
        minimumBudget: form.minimumBudget,
        maximumBudget: form.maximumBudget,
        status: ServiceRequestStatus.open,
        offerCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      await repository.create(request);
      _lastError = null;
      return repository.byId(request.id) ?? request;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setSaving(false);
    }
  }

  Future<ServiceRequest> updateRequest({
    required String id,
    required ServiceRequestFormData form,
  }) async {
    final current = repository.byId(id);
    if (current == null) {
      throw StateError('Service request $id was not found.');
    }
    if (!current.status.canEdit) {
      throw StateError('This service request can no longer be edited.');
    }

    _setSaving(true);
    try {
      final updated = current.copyWith(
        title: form.title.trim(),
        categoryId: form.category.id,
        categoryName: form.category.name,
        description: form.description.trim(),
        location: form.location.trim(),
        preferredDate: form.preferredDate,
        preferredTime: form.preferredTime,
        urgency: form.urgency,
        minimumBudget: form.minimumBudget,
        maximumBudget: form.maximumBudget,
        clearMinimumBudget: form.minimumBudget == null,
        clearMaximumBudget: form.maximumBudget == null,
      );
      await repository.update(updated);
      _lastError = null;
      return repository.byId(updated.id) ?? updated;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> cancel(String id) async {
    final request = repository.byId(id);
    if (request == null) return;

    _setSaving(true);
    try {
      await repository.update(
        request.copyWith(status: ServiceRequestStatus.cancelled),
      );
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> deleteDraft(String id) async {
    final request = repository.byId(id);
    if (request == null || request.status != ServiceRequestStatus.draft) {
      return;
    }
    _setSaving(true);
    try {
      await repository.delete(id);
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setSaving(false);
    }
  }

  void refreshFromRepository() {
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  static String createRequestId() =>
      'SR-${DateTime.now().microsecondsSinceEpoch}';
}
