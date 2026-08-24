import 'account_identity.dart';
import 'product_listing.dart';

enum ProductPurchaseStatus {
  submitted,
  accepted,
  declined,
  cancelled,
}

extension ProductPurchaseStatusDetails on ProductPurchaseStatus {
  String get code => name;

  String get label => switch (this) {
        ProductPurchaseStatus.submitted => 'Awaiting Seller',
        ProductPurchaseStatus.accepted => 'Accepted',
        ProductPurchaseStatus.declined => 'Declined',
        ProductPurchaseStatus.cancelled => 'Cancelled',
      };
}

class MarketplaceProduct {
  final String id;
  final String publicListingId;
  final String sellerPublicName;
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
  final String buyerNote;
  final String sellerNote;
  final ProductPurchaseStatus status;
  final int version;
  final DateTime submittedAt;
  final DateTime? decidedAt;
  final DateTime? cancelledAt;
  final DateTime updatedAt;

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
    required this.buyerNote,
    required this.sellerNote,
    required this.status,
    required this.version,
    required this.submittedAt,
    required this.updatedAt,
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
      buyerNote: '${json['buyerNote'] ?? ''}',
      sellerNote: '${json['sellerNote'] ?? ''}',
      status: _purchaseStatus(json['status']),
      version: _integer(json, 'version'),
      submittedAt: DateTime.parse(_requiredString(json, 'submittedAt')),
      decidedAt: _optionalDate(json['decidedAt']),
      cancelledAt: _optionalDate(json['cancelledAt']),
      updatedAt: DateTime.parse(_requiredString(json, 'updatedAt')),
    );
  }

  String get unitPriceLabel => _money(currency, unitPriceMinor);

  String get subtotalLabel => _money(currency, subtotalMinor);

  bool get canCancel => status == ProductPurchaseStatus.submitted;
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
