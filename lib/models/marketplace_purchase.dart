import 'account_identity.dart';
import 'product_listing.dart';

enum ProductPurchaseStatus {
  submitted,
  accepted,
  fulfilled,
  completed,
  declined,
  cancelled,
}

extension ProductPurchaseStatusDetails on ProductPurchaseStatus {
  String get code => name;

  String get label => switch (this) {
        ProductPurchaseStatus.submitted => 'Awaiting Seller',
        ProductPurchaseStatus.accepted => 'Accepted',
        ProductPurchaseStatus.fulfilled => 'Fulfilled — awaiting buyer confirmation',
        ProductPurchaseStatus.completed => 'Completed',
        ProductPurchaseStatus.declined => 'Declined',
        ProductPurchaseStatus.cancelled => 'Cancelled',
      };
}

class MarketplaceProduct {
  final String id;
  final String publicListingId;
  final String sellerPublicName;
  final String? sellerPublicProfileId;
  final HDCPlatformRole sellerRole;
  final String categoryCode;
  final String title;
  final String description;
  final ProductItemCondition condition;
  final String currency;
  final int unitPriceMinor;
  final int stockQuantity;
  final DateTime publishedAt;
  final DateTime updatedAt;

  const MarketplaceProduct({
    required this.id,
    required this.publicListingId,
    required this.sellerPublicName,
    this.sellerPublicProfileId,
    required this.sellerRole,
    required this.categoryCode,
    required this.title,
    required this.description,
    required this.condition,
    required this.currency,
    required this.unitPriceMinor,
    required this.stockQuantity,
    required this.publishedAt,
    required this.updatedAt,
  });

  factory MarketplaceProduct.fromJson(Map<String, dynamic> json) {
    final sellerRole = parseHDCPlatformRole(json['sellerRole']);
    if (sellerRole != HDCPlatformRole.seller &&
        sellerRole != HDCPlatformRole.supplier &&
        sellerRole != HDCPlatformRole.store) {
      throw const FormatException('Invalid HDC marketplace seller role.');
    }
    return MarketplaceProduct(
      id: _requiredString(json, 'id'),
      publicListingId: _requiredString(json, 'publicListingId'),
      sellerPublicName: _requiredString(json, 'sellerPublicName'),
      sellerPublicProfileId: json['sellerPublicProfileId'] is String
          ? json['sellerPublicProfileId'] as String
          : null,
      sellerRole: sellerRole!,
      categoryCode: _requiredString(json, 'categoryCode'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      condition: _condition(json['condition']),
      currency: _requiredString(json, 'currency'),
      unitPriceMinor: _integer(json, 'unitPriceMinor'),
      stockQuantity: _integer(json, 'stockQuantity'),
      publishedAt: DateTime.parse(_requiredString(json, 'publishedAt')),
      updatedAt: DateTime.parse(_requiredString(json, 'updatedAt')),
    );
  }

  String get priceLabel => _money(currency, unitPriceMinor);

  String get categoryLabel => _categoryLabel(categoryCode);
}

class PurchaseFulfillmentProposal {
  final String method;
  final String location;
  final String timing;
  final int feeMinor;
  final int totalMinor;

  const PurchaseFulfillmentProposal({
    required this.method,
    required this.location,
    required this.timing,
    required this.feeMinor,
    required this.totalMinor,
  });

  factory PurchaseFulfillmentProposal.fromJson(Map<String, dynamic> json) {
    final method = _requiredString(json, 'method');
    if (method != 'pickup' && method != 'delivery') {
      throw const FormatException('Invalid HDC fulfillment method.');
    }
    return PurchaseFulfillmentProposal(
      method: method,
      location: _requiredString(json, 'location'),
      timing: _requiredString(json, 'timing'),
      feeMinor: _integer(json, 'feeMinor'),
      totalMinor: _integer(json, 'totalMinor'),
    );
  }

  String get methodLabel => method == 'pickup' ? 'Pickup' : 'Delivery';
}

class ProductPurchaseRequest {
  final String id;
  final String publicPurchaseId;
  final String listingId;
  final String publicListingId;
  final String listingTitle;
  final String sellerPublicName;
  final HDCPlatformRole sellerRole;
  final String buyerDisplayName;
  final String buyerPublicMemberId;
  final int quantity;
  final String currency;
  final int unitPriceMinor;
  final int subtotalMinor;
  final PurchaseFulfillmentProposal? fulfillment;
  final String buyerNote;
  final String sellerNote;
  final String? cancellationRequestedBy;
  final String? cancellationReason;
  final DateTime? cancellationRequestedAt;
  final String cancellationResponseNote;
  final DateTime? stockReleasedAt;
  final ProductPurchaseStatus status;
  final int version;
  final DateTime submittedAt;
  final DateTime? decidedAt;
  final DateTime? cancelledAt;
  final DateTime updatedAt;
  final List<ProductPurchaseEvent> events;

  const ProductPurchaseRequest({
    required this.id,
    required this.publicPurchaseId,
    required this.listingId,
    required this.publicListingId,
    required this.listingTitle,
    required this.sellerPublicName,
    required this.sellerRole,
    required this.buyerDisplayName,
    required this.buyerPublicMemberId,
    required this.quantity,
    required this.currency,
    required this.unitPriceMinor,
    required this.subtotalMinor,
    this.fulfillment,
    required this.buyerNote,
    required this.sellerNote,
    this.cancellationRequestedBy,
    this.cancellationReason,
    this.cancellationRequestedAt,
    this.cancellationResponseNote = '',
    this.stockReleasedAt,
    required this.status,
    required this.version,
    required this.submittedAt,
    required this.updatedAt,
    this.events = const [],
    this.decidedAt,
    this.cancelledAt,
  });

  factory ProductPurchaseRequest.fromJson(Map<String, dynamic> json) {
    final sellerRole = parseHDCPlatformRole(json['sellerRole']);
    if (sellerRole != HDCPlatformRole.seller &&
        sellerRole != HDCPlatformRole.supplier &&
        sellerRole != HDCPlatformRole.store) {
      throw const FormatException('Invalid HDC purchase seller role.');
    }
    return ProductPurchaseRequest(
      id: _requiredString(json, 'id'),
      publicPurchaseId: _requiredString(json, 'publicPurchaseId'),
      listingId: _requiredString(json, 'listingId'),
      publicListingId: _requiredString(json, 'publicListingId'),
      listingTitle: _requiredString(json, 'listingTitle'),
      sellerPublicName: _requiredString(json, 'sellerPublicName'),
      sellerRole: sellerRole!,
      buyerDisplayName: _requiredString(json, 'buyerDisplayName'),
      buyerPublicMemberId: _requiredString(json, 'buyerPublicMemberId'),
      quantity: _integer(json, 'quantity'),
      currency: _requiredString(json, 'currency'),
      unitPriceMinor: _integer(json, 'unitPriceMinor'),
      subtotalMinor: _integer(json, 'subtotalMinor'),
      fulfillment: json['fulfillment'] is Map
          ? PurchaseFulfillmentProposal.fromJson(
              Map<String, dynamic>.from(json['fulfillment'] as Map),
            )
          : null,
      buyerNote: '${json['buyerNote'] ?? ''}',
      sellerNote: '${json['sellerNote'] ?? ''}',
      cancellationRequestedBy: json['cancellationRequestedBy'] is String
          ? json['cancellationRequestedBy'] as String : null,
      cancellationReason: json['cancellationReason'] is String
          ? json['cancellationReason'] as String : null,
      cancellationRequestedAt: _optionalDate(json['cancellationRequestedAt']),
      cancellationResponseNote: '${json['cancellationResponseNote'] ?? ''}',
      stockReleasedAt: _optionalDate(json['stockReleasedAt']),
      status: _purchaseStatus(json['status']),
      version: _integer(json, 'version'),
      submittedAt: DateTime.parse(_requiredString(json, 'submittedAt')),
      decidedAt: _optionalDate(json['decidedAt']),
      cancelledAt: _optionalDate(json['cancelledAt']),
      updatedAt: DateTime.parse(_requiredString(json, 'updatedAt')),
      events: (json['events'] as List<dynamic>? ?? const [])
          .map((event) => ProductPurchaseEvent.fromJson(
                Map<String, dynamic>.from(event as Map),
              ))
          .toList(growable: false),
    );
  }

  String get unitPriceLabel => _money(currency, unitPriceMinor);

  String get subtotalLabel => _money(currency, subtotalMinor);

  String get fulfillmentFeeLabel =>
      _money(currency, fulfillment?.feeMinor ?? 0);

  String get proposedTotalLabel =>
      _money(currency, fulfillment?.totalMinor ?? subtotalMinor);

  bool get canCancel => status == ProductPurchaseStatus.submitted;
  bool get canRequestCancellation =>
      status == ProductPurchaseStatus.accepted && cancellationRequestedBy == null;
  bool get buyerCanRespondCancellation =>
      status == ProductPurchaseStatus.accepted && cancellationRequestedBy == 'seller';
  bool get sellerCanRespondCancellation =>
      status == ProductPurchaseStatus.accepted && cancellationRequestedBy == 'buyer';
  String get statusLabel => stockReleasedAt != null
      ? 'Cancelled by agreement' : status.label;
}

class ProductPurchaseEvent {
  final String type;
  final ProductPurchaseStatus? fromStatus;
  final ProductPurchaseStatus toStatus;
  final DateTime occurredAt;
  final String note;

  const ProductPurchaseEvent({
    required this.type,
    required this.fromStatus,
    required this.toStatus,
    required this.occurredAt,
    required this.note,
  });

  factory ProductPurchaseEvent.fromJson(Map<String, dynamic> json) =>
      ProductPurchaseEvent(
        type: _requiredString(json, 'type'),
        fromStatus: json['fromStatus'] == null
            ? null
            : _purchaseStatus(json['fromStatus']),
        toStatus: _purchaseStatus(json['toStatus']),
        occurredAt: DateTime.parse(_requiredString(json, 'occurredAt')),
        note: '${json['note'] ?? ''}',
      );

  String get typeLabel => switch (type) {
        'cancellation_requested' => 'Cancellation requested',
        'cancellation_declined' => 'Cancellation declined',
        _ => toStatus.label,
      };
}

ProductPurchaseStatus _purchaseStatus(Object? value) {
  final code = '$value'.trim().toLowerCase();
  return ProductPurchaseStatus.values.firstWhere(
    (status) => status.code == code,
    orElse: () => throw const FormatException(
      'Invalid HDC purchase-request status.',
    ),
  );
}

ProductItemCondition _condition(Object? value) {
  final code = '$value'.trim().toLowerCase();
  return ProductItemCondition.values.firstWhere(
    (condition) => condition.code == code,
    orElse: () => throw const FormatException(
      'Invalid HDC marketplace product condition.',
    ),
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid HDC marketplace response.');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.isFinite || value != value.round()) {
    throw const FormatException('Invalid HDC marketplace number.');
  }
  return value.toInt();
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  return DateTime.parse('$value');
}

String _money(String currency, int minor) {
  final whole = minor ~/ 100;
  final decimal = (minor % 100).toString().padLeft(2, '0');
  final symbol = currency == 'PHP' ? '₱' : '$currency ';
  return '$symbol$whole.$decimal';
}

String _categoryLabel(String code) => switch (code) {
      'computers' => 'Desktop computers',
      'laptops' => 'Laptops',
      'mobile_devices' => 'Mobile devices',
      'pos_equipment' => 'POS and business equipment',
      'networking' => 'Networking',
      'parts_components' => 'Parts and components',
      'accessories' => 'Accessories and peripherals',
      'software_licenses' => 'Software and licenses',
      _ => 'Other technology',
    };
