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
    _purchaseError = null;
    _isLoadingPurchases = false;
    final version = _bindingVersion;
    scheduleMicrotask(() {
      if (_disposed || version != _bindingVersion) return;
      notifyListeners();
      if (client == null) return;
      unawaited(refreshCatalog());
      if (userId != null) unawaited(refreshPurchases());
    });
  }

  Future<void> refreshCatalog() async {
    final api = client;
    if (_disposed || api == null || _isLoadingCatalog) return;
    _isLoadingCatalog = true;
    _catalogError = null;
    _announce();
    try {
      final response = await api.getPublic('/api/commerce/catalog');
      final products = _objectList(response['listings'])
          .map(MarketplaceProduct.fromJson)
          .toList(growable: false);
      if (_disposed) return;
      _products = List<MarketplaceProduct>.unmodifiable(products);
    } on Object catch (error) {
      if (!_disposed) _catalogError = error;
    } finally {
      if (!_disposed) {
        _isLoadingCatalog = false;
        _announce();
      }
    }
  }

  Future<void> refreshPurchases() async {
    final api = client;
    final userId = _boundUserId;
    if (_disposed || api == null || userId == null || _isLoadingPurchases) {
      return;
    }
    final version = _bindingVersion;
    _isLoadingPurchases = true;
    _purchaseError = null;
    _announce();
    try {
      final response = await api.get('/api/commerce/buyer-dashboard');
      if (!_isCurrent(userId, version)) return;
      _purchaseRequests = List<ProductPurchaseRequest>.unmodifiable(
        _objectList(response['purchaseRequests'])
            .map(ProductPurchaseRequest.fromJson),
      );
    } on Object catch (error) {
      if (_isCurrent(userId, version)) _purchaseError = error;
    } finally {
      if (_isCurrent(userId, version)) {
        _isLoadingPurchases = false;
        _announce();
      }
    }
  }

  Future<ProductPurchaseRequest> requestPurchase({
    required MarketplaceProduct product,
    required int quantity,
    required String buyerNote,
  }) async {
    return _writePurchase(
      '/api/commerce/purchase-requests',
      {
        'listingId': product.id,
        'quantity': quantity,
        'buyerNote': buyerNote,
        'clientRequestId': _newUuid(),
      },
      create: true,
    );
  }

  Future<ProductPurchaseRequest> cancelPurchase(
    ProductPurchaseRequest request,
  ) {
    return _writePurchase(
      '/api/commerce/purchase-requests/${request.id}/status',
      {
        'action': 'cancel',
        'version': request.version,
        'note': '',
      },
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
      if (_isCurrent(userId, version)) _upsert(request);
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

String _newUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
