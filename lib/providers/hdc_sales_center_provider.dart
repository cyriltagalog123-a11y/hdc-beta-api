import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';
import '../models/account_identity.dart';
import '../models/marketplace_purchase.dart';
import '../models/product_listing.dart';

class HdcSalesCenterProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;

  String? _boundUserId;
  Set<HDCPlatformRole> _identitySellingRoles = const {};
  List<HdcSellingProfile> _sellingProfiles = const [];
  List<ProductListing> _listings = const [];
  List<ProductPurchaseRequest> _purchaseRequests = const [];
  int _activeListingCount = 0;
  int _draftListingCount = 0;
  int _pausedListingCount = 0;
  int _soldListingCount = 0;
  int _lowStockListingCount = 0;
  int _pendingPurchaseRequestCount = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _lastError;
  int _bindingVersion = 0;
  bool _disposed = false;

  HdcSalesCenterProvider({this.client});

  List<HdcSellingProfile> get sellingProfiles =>
      List<HdcSellingProfile>.unmodifiable(_sellingProfiles);
  List<ProductListing> get listings =>
      List<ProductListing>.unmodifiable(_listings);
  List<ProductPurchaseRequest> get purchaseRequests =>
      List<ProductPurchaseRequest>.unmodifiable(_purchaseRequests);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get backendAvailable => client != null;
  Object? get lastError => _lastError;
  bool get canSell => _identitySellingRoles.isNotEmpty;
  bool get hasListingHistory => _listings.isNotEmpty;
  int get activeListingCount => _activeListingCount;
  int get draftListingCount => _draftListingCount;
  int get pausedListingCount => _pausedListingCount;
  int get soldListingCount => _soldListingCount;
  int get lowStockListingCount => _lowStockListingCount;
  int get pendingPurchaseRequestCount => _pendingPurchaseRequestCount;

  void bindIdentity(AccountIdentity? identity) {
    if (_disposed) return;
    final userId = identity?.id;
    final roles = Set<HDCPlatformRole>.unmodifiable(
      identity?.platformRoles.where(_isSellingRole) ??
          const <HDCPlatformRole>[],
    );
    if (_boundUserId == userId && setEquals(_identitySellingRoles, roles)) {
      return;
    }

    final accountChanged = _boundUserId != userId;
    _boundUserId = userId;
    _identitySellingRoles = roles;
    if (!accountChanged) {
      _announceSoon();
      return;
    }

    _bindingVersion += 1;
    _sellingProfiles = const [];
    _listings = const [];
    _purchaseRequests = const [];
    _clearSummary();
    _isLoading = false;
    _isSaving = false;
    _lastError = null;
    final version = _bindingVersion;
    scheduleMicrotask(() {
      if (_disposed || version != _bindingVersion) return;
      notifyListeners();
      if (userId != null && client != null) unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed || api == null || userId == null || _isLoading) return;
    final version = _bindingVersion;
    _isLoading = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.get('/api/commerce/seller-dashboard');
      if (!_isCurrent(userId, version)) return;
      final receivedProfiles = List<HdcSellingProfile>.unmodifiable(
        _objectList(response['sellingProfiles'])
            .map(HdcSellingProfile.fromJson),
      );
      final summary = _requiredObject(response, 'summary');
      final receivedListings = _objectList(response['listings'])
          .map(ProductListing.fromJson)
          .toList(growable: false);
      final receivedPurchaseRequests =
          _objectList(response['purchaseRequests'])
              .map(ProductPurchaseRequest.fromJson)
              .toList(growable: false);
      if (receivedListings.any((item) => item.sellerUserId != userId)) {
        throw const HdcWorkflowException(
          code: 'invalid_server_response',
          message: 'HDC rejected a marketplace response for another account.',
        );
      }
      _sellingProfiles = receivedProfiles;
      _listings = List<ProductListing>.unmodifiable(receivedListings);
      _purchaseRequests =
          List<ProductPurchaseRequest>.unmodifiable(receivedPurchaseRequests);
      _activeListingCount = _summaryCount(summary, 'activeListings');
      _draftListingCount = _summaryCount(summary, 'draftListings');
      _pausedListingCount = _summaryCount(summary, 'pausedListings');
      _soldListingCount = _summaryCount(summary, 'soldListings');
      _lowStockListingCount = _summaryCount(summary, 'lowStockListings');
      _pendingPurchaseRequestCount =
          _summaryCount(summary, 'pendingPurchaseRequests');
    } on Object catch (error) {
      if (_isCurrent(userId, version)) _lastError = error;
    } finally {
      if (_isCurrent(userId, version)) {
        _isLoading = false;
        _announce();
      }
    }
  }

  Future<ProductListing> createListing(Map<String, Object?> body) async {
    return _writeListing('/api/commerce/listings', body, create: true);
  }

  Future<ProductListing> updateListing(
    String listingId,
    Map<String, Object?> body,
  ) async {
    return _writeListing(
      '/api/commerce/listings/$listingId',
      body,
      create: false,
    );
  }

  Future<ProductListing> changeStatus(
    ProductListing listing,
    ProductListingStatus status,
  ) {
    return updateListing(
      listing.id,
      listing.writeBody(
        nextStatus: status,
        nextStockQuantity:
            status == ProductListingStatus.sold ? 0 : listing.stockQuantity,
      ),
    );
  }

  Future<ProductPurchaseRequest> decidePurchaseRequest(
    ProductPurchaseRequest request, {
    required String action,
    required String note,
  }) async {
    if (action != 'accept' && action != 'decline') {
      throw ArgumentError.value(action, 'action', 'Unsupported seller action.');
    }
    final api = client;
    final userId = _boundUserId;
    if (_disposed || api == null || userId == null) {
      throw const HdcWorkflowException(
        code: 'commerce_backend_unavailable',
        message: 'HDC marketplace services require the HDC API.',
      );
    }
    if (_isSaving) {
      throw const HdcWorkflowException(
        code: 'commerce_request_in_progress',
        message: 'Another marketplace change is still being saved.',
      );
    }
    final bindingVersion = _bindingVersion;
    _isSaving = true;
    _lastError = null;
    _announce();
    try {
      final response = await api.put(
        '/api/commerce/purchase-requests/${request.id}/status',
        body: {
          'action': action,
          'version': request.version,
          'note': note,
        },
      );
      final updated = ProductPurchaseRequest.fromJson(
        _requiredObject(response, 'purchaseRequest'),
      );
      if (_isCurrent(userId, bindingVersion)) {
        _upsertPurchaseRequest(updated);
        unawaited(refresh());
      }
      return updated;
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

  Future<ProductListing> _writeListing(
    String path,
    Map<String, Object?> body, {
    required bool create,
  }) async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed || api == null || userId == null) {
      throw const HdcWorkflowException(
        code: 'commerce_backend_unavailable',
        message: 'HDC marketplace services require the HDC API.',
      );
    }
    final version = _bindingVersion;
    _isSaving = true;
    _lastError = null;
    _announce();
    try {
      final response = create
          ? await api.post(path, body: body)
          : await api.put(path, body: body);
      final listing = ProductListing.fromJson(
        _requiredObject(response, 'listing'),
      );
      if (_isCurrent(userId, version)) _upsert(listing);
      return listing;
    } on Object catch (error) {
      if (_isCurrent(userId, version)) _lastError = error;
      rethrow;
    } finally {
      if (_isCurrent(userId, version)) {
        _isSaving = false;
        _announce();
      }
    }
  }

  void _upsert(ProductListing listing) {
    final values = [..._listings];
    final index = values.indexWhere((item) => item.id == listing.id);
    final previous = index == -1 ? null : values[index];
    _applySummaryDelta(previous, listing);
    if (index == -1) {
      values.insert(0, listing);
    } else {
      values[index] = listing;
    }
    values.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _listings = List<ProductListing>.unmodifiable(values);
  }

  void _upsertPurchaseRequest(ProductPurchaseRequest request) {
    final values = [..._purchaseRequests];
    final index = values.indexWhere((item) => item.id == request.id);
    final previous = index == -1 ? null : values[index];
    if (previous?.status == ProductPurchaseStatus.submitted &&
        request.status != ProductPurchaseStatus.submitted) {
      if (_pendingPurchaseRequestCount > 0) {
        _pendingPurchaseRequestCount -= 1;
      }
    }
    if (index == -1) {
      values.insert(0, request);
    } else {
      values[index] = request;
    }
    values.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    _purchaseRequests = List<ProductPurchaseRequest>.unmodifiable(values);
  }

  void _clearSummary() {
    _activeListingCount = 0;
    _draftListingCount = 0;
    _pausedListingCount = 0;
    _soldListingCount = 0;
    _lowStockListingCount = 0;
    _pendingPurchaseRequestCount = 0;
  }

  void _applySummaryDelta(
    ProductListing? previous,
    ProductListing current,
  ) {
    if (previous != null) {
      _changeStatusCount(previous.status, -1);
      if (_isLowStock(previous)) _lowStockListingCount -= 1;
    }
    _changeStatusCount(current.status, 1);
    if (_isLowStock(current)) _lowStockListingCount += 1;
  }

  void _changeStatusCount(ProductListingStatus status, int delta) {
    switch (status) {
      case ProductListingStatus.active:
        _activeListingCount += delta;
        break;
      case ProductListingStatus.draft:
        _draftListingCount += delta;
        break;
      case ProductListingStatus.paused:
        _pausedListingCount += delta;
        break;
      case ProductListingStatus.sold:
        _soldListingCount += delta;
        break;
      case ProductListingStatus.archived:
        break;
    }
  }

  bool _isCurrent(String userId, int version) =>
      !_disposed && _boundUserId == userId && _bindingVersion == version;

  void _announceSoon() {
    final version = _bindingVersion;
    scheduleMicrotask(() {
      if (!_disposed && version == _bindingVersion) notifyListeners();
    });
  }

  void _announce() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

bool _isSellingRole(HDCPlatformRole role) =>
    role == HDCPlatformRole.seller ||
    role == HDCPlatformRole.supplier ||
    role == HDCPlatformRole.store;

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) {
    throw const HdcWorkflowException(
      code: 'invalid_server_response',
      message: 'HDC returned an invalid marketplace response.',
    );
  }
  return value.map((item) {
    if (item is! Map) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned an invalid marketplace response.',
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
      message: 'HDC returned an invalid marketplace response.',
    );
  }
  return value.map((key, value) => MapEntry('$key', value));
}

int _summaryCount(Map<String, dynamic> summary, String key) {
  final value = summary[key];
  if (value is! num || !value.isFinite || value < 0 || value != value.round()) {
    throw const HdcWorkflowException(
      code: 'invalid_server_response',
      message: 'HDC returned invalid marketplace statistics.',
    );
  }
  return value.toInt();
}

bool _isLowStock(ProductListing listing) =>
    listing.status == ProductListingStatus.active &&
    listing.stockQuantity > 0 &&
    listing.stockQuantity <= 3;
