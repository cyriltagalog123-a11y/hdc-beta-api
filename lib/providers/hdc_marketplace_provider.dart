import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';
import '../models/account_identity.dart';
import '../models/marketplace_purchase.dart';

class HdcMarketplaceProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;

  String? _boundUserId;
  bool _bindingInitialized = false;
  List<MarketplaceProduct> _products = const [];
  List<ProductPurchaseRequest> _purchaseRequests = const [];
  bool _isLoadingCatalog = false;
  bool _isLoadingPurchases = false;
  bool _isSaving = false;
  Object? _catalogError;
  Object? _purchaseError;
  int _bindingVersion = 0;
  int _purchaseReadGeneration = 0;
  int _catalogReadGeneration = 0;
  String? _nextCatalogCursor;
  Map<String, String> _catalogFilters = const {};
  List<String> _availableCurrencies = const [];
  String? _nextPurchaseCursor;
  bool _disposed = false;

  HdcMarketplaceProvider({this.client});

  List<MarketplaceProduct> get products =>
      List<MarketplaceProduct>.unmodifiable(_products);
  List<ProductPurchaseRequest> get purchaseRequests =>
      List<ProductPurchaseRequest>.unmodifiable(_purchaseRequests);
  bool get authenticated => _boundUserId != null;
  bool get isLoadingCatalog => _isLoadingCatalog;
  bool get isLoadingPurchases => _isLoadingPurchases;
  bool get isSaving => _isSaving;
  Object? get catalogError => _catalogError;
  Object? get purchaseError => _purchaseError;
  int get availableProductCount => _products.length;
  bool get hasMoreProducts => _nextCatalogCursor != null;
  List<String> get availableCurrencies => _availableCurrencies;
  bool get hasMorePurchases => _nextPurchaseCursor != null;
  int get pendingPurchaseCount => _purchaseRequests
      .where((item) => item.status == ProductPurchaseStatus.submitted)
      .length;

  void bindIdentity(AccountIdentity? identity) {
    if (_disposed) return;
    final userId = identity?.id;
    if (_bindingInitialized && _boundUserId == userId) return;
    _bindingInitialized = true;
    _boundUserId = userId;
    _bindingVersion += 1;
    _purchaseRequests = const [];
    _nextPurchaseCursor = null;
    _purchaseReadGeneration += 1;
    _purchaseError = null;
    _isLoadingPurchases = false;
    _isSaving = false;
    final version = _bindingVersion;
    scheduleMicrotask(() {
      if (_disposed || version != _bindingVersion) return;
      notifyListeners();
      if (client == null) return;
      unawaited(refreshCatalog());
      if (userId != null) unawaited(refreshPurchases());
    });
  }

  Future<void> refreshCatalog() => _readCatalog(loadMore: false);

  Future<void> setCatalogFilters(Map<String, String> filters) {
    if (mapEquals(_catalogFilters, filters)) return refreshCatalog();
    _catalogFilters = Map<String, String>.unmodifiable(filters);
    _nextCatalogCursor = null;
    _products = const [];
    return refreshCatalog();
  }

  Future<void> loadMoreCatalog() => _readCatalog(loadMore: true);

  Future<void> _readCatalog({required bool loadMore}) async {
    final api = client;
    final cursor = _nextCatalogCursor;
    if (_disposed || api == null || (loadMore && _isLoadingCatalog) ||
        (loadMore && cursor == null)) {
      return;
    }
    final generation = ++_catalogReadGeneration;
    _isLoadingCatalog = true;
    _catalogError = null;
    _announce();
    try {
      final response = await api.getPublic(Uri(path: '/api/commerce/catalog',
        queryParameters: {
          ..._catalogFilters,
          if (loadMore) 'cursor': cursor!,
        }).toString());
      final products = _objectList(
        response['listings'],
      ).map(MarketplaceProduct.fromJson).toList(growable: false);
      if (_disposed || generation != _catalogReadGeneration) return;
      _nextCatalogCursor = _cursor(response['nextCursor']);
      final currencies = response['availableCurrencies'];
      if (currencies is List) {
        _availableCurrencies = List<String>.unmodifiable(
            currencies.whereType<String>());
      }
      _products = List<MarketplaceProduct>.unmodifiable(loadMore
          ? _mergeProducts(_products, products)
          : products);
    } on Object catch (error) {
      if (!_disposed && generation == _catalogReadGeneration) _catalogError = error;
    } finally {
      if (!_disposed && generation == _catalogReadGeneration) {
        _isLoadingCatalog = false;
        _announce();
      }
    }
  }

  Future<void> refreshPurchases() async {
    await _readPurchases(loadMore: false);
  }

  Future<void> loadMorePurchases() => _readPurchases(loadMore: true);

  Future<void> _readPurchases({required bool loadMore}) async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed || api == null || userId == null || _isLoadingPurchases) {
      return;
    }
    final cursor = _nextPurchaseCursor;
    if (loadMore && cursor == null) return;
    final version = _bindingVersion;
    final generation = ++_purchaseReadGeneration;
    _isLoadingPurchases = true;
    _purchaseError = null;
    _announce();
    try {
      final response = await api.get(loadMore
          ? '/api/commerce/buyer-dashboard?cursor=${Uri.encodeQueryComponent(cursor!)}'
          : '/api/commerce/buyer-dashboard');
      if (!_isCurrent(userId, version) || generation != _purchaseReadGeneration) {
        return;
      }
      final received = _objectList(response['purchaseRequests'])
          .map(ProductPurchaseRequest.fromJson).toList(growable: false);
      _nextPurchaseCursor = _cursor(response['nextCursor']);
      _purchaseRequests = List<ProductPurchaseRequest>.unmodifiable(loadMore
          ? _mergePurchases(_purchaseRequests, received)
          : received);
    } on Object catch (error) {
      if (_isCurrent(userId, version) && generation == _purchaseReadGeneration) {
        _purchaseError = error;
      }
    } finally {
      if (_isCurrent(userId, version) &&
          generation == _purchaseReadGeneration) {
        _isLoadingPurchases = false;
        _announce();
      }
    }
  }

  Future<ProductPurchaseRequest> requestPurchase({
    required MarketplaceProduct product,
    required int quantity,
    required String buyerNote,
    required String fulfillmentMethod,
    required String fulfillmentLocation,
    required String fulfillmentTiming,
    required int fulfillmentFeeMinor,
  }) async {
    return _writePurchase('/api/commerce/purchase-requests', {
      'listingId': product.id,
      'quantity': quantity,
      'buyerNote': buyerNote,
      'fulfillmentMethod': fulfillmentMethod,
      'fulfillmentLocation': fulfillmentLocation,
      'fulfillmentTiming': fulfillmentTiming,
      'fulfillmentFeeMinor': fulfillmentFeeMinor,
      'clientRequestId': _newUuid(),
    }, create: true);
  }

  Future<ProductPurchaseRequest> cancelPurchase(
    ProductPurchaseRequest request,
  ) {
    return _writePurchase(
      '/api/commerce/purchase-requests/${request.id}/status',
      {'action': 'cancel', 'version': request.version, 'note': ''},
      create: false,
    );
  }

  Future<ProductPurchaseRequest> actOnCancellation(
    ProductPurchaseRequest request, {
    required String action,
    required String note,
  }) {
    if (action != 'request' && action != 'approve' && action != 'decline') {
      throw ArgumentError.value(action, 'action', 'Invalid cancellation action.');
    }
    return _writePurchase(
      '/api/commerce/purchase-requests/${request.id}/cancellation',
      {'action': action, 'version': request.version, 'note': note},
      create: false,
    );
  }

  Future<ProductPurchaseRequest> _writePurchase(
    String path,
    Map<String, Object?> body, {
    required bool create,
  }) async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed || api == null || userId == null) {
      throw const HdcWorkflowException(
        code: 'authentication_required',
        message: 'Sign in to request a marketplace purchase.',
      );
    }
    if (_isSaving) {
      throw const HdcWorkflowException(
        code: 'commerce_request_in_progress',
        message: 'Another marketplace request is still being saved.',
      );
    }
    final version = _bindingVersion;
    _isSaving = true;
    _purchaseError = null;
    _announce();
    try {
      final response = create
          ? await api.post(path, body: body)
          : await api.put(path, body: body);
      final request = ProductPurchaseRequest.fromJson(
        _requiredObject(response, 'purchaseRequest'),
      );
      if (!_isCurrent(userId, version)) {
        throw const HdcWorkflowException(
          code: 'account_context_changed',
          message: 'Your account changed. Refresh before continuing.',
        );
      }
      _purchaseReadGeneration += 1;
      _isLoadingPurchases = false;
      _upsert(request);
      return request;
    } on Object catch (error) {
      if (_isCurrent(userId, version)) _purchaseError = error;
      rethrow;
    } finally {
      if (_isCurrent(userId, version)) {
        _isSaving = false;
        _announce();
      }
    }
  }

  void _upsert(ProductPurchaseRequest request) {
    final values = [..._purchaseRequests];
    final index = values.indexWhere((item) => item.id == request.id);
    if (index == -1) {
      values.insert(0, request);
    } else {
      values[index] = request;
    }
    values.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    _purchaseRequests = List<ProductPurchaseRequest>.unmodifiable(values);
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

String? _cursor(Object? value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return value;
  throw const HdcWorkflowException(
    code: 'invalid_server_response',
    message: 'HDC returned an invalid marketplace page.',
  );
}

List<MarketplaceProduct> _mergeProducts(
  List<MarketplaceProduct> current,
  List<MarketplaceProduct> received,
) {
  final byId = {for (final item in current) item.id: item};
  for (final item in received) {
    byId[item.id] = item;
  }
  return byId.values.toList(growable: false);
}

List<ProductPurchaseRequest> _mergePurchases(
  List<ProductPurchaseRequest> current,
  List<ProductPurchaseRequest> received,
) {
  final byId = {for (final item in current) item.id: item};
  for (final item in received) {
    byId[item.id] = item;
  }
  return byId.values.toList(growable: false);
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) {
    throw const HdcWorkflowException(
      code: 'invalid_server_response',
      message: 'HDC returned an invalid marketplace response.',
    );
  }
  return value
      .map((item) {
        if (item is! Map) {
          throw const HdcWorkflowException(
            code: 'invalid_server_response',
            message: 'HDC returned an invalid marketplace response.',
          );
        }
        return item.map((key, value) => MapEntry('$key', value));
      })
      .toList(growable: false);
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

String _newUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
