import 'account_identity.dart';

enum ProductListingStatus {
  draft,
  active,
  paused,
  sold,
  archived,
}

extension ProductListingStatusDetails on ProductListingStatus {
  String get code => name;

  String get label => switch (this) {
        ProductListingStatus.draft => 'Draft',
        ProductListingStatus.active => 'Selling',
        ProductListingStatus.paused => 'Paused',
        ProductListingStatus.sold => 'Sold',
        ProductListingStatus.archived => 'Archived',
      };
}

ProductListingStatus _parseStatus(Object? value) {
  final code = '$value'.trim().toLowerCase();
  return ProductListingStatus.values.firstWhere(
    (status) => status.code == code,
    orElse: () => throw const FormatException(
      'Invalid HDC product-listing status.',
    ),
  );
}

enum ProductItemCondition {
  newItem,
  openBox,
  used,
  refurbished,
  forParts,
}

extension ProductItemConditionDetails on ProductItemCondition {
  String get code => switch (this) {
        ProductItemCondition.newItem => 'new',
        ProductItemCondition.openBox => 'open_box',
        ProductItemCondition.used => 'used',
        ProductItemCondition.refurbished => 'refurbished',
        ProductItemCondition.forParts => 'for_parts',
      };

  String get label => switch (this) {
        ProductItemCondition.newItem => 'New',
        ProductItemCondition.openBox => 'Open box',
        ProductItemCondition.used => 'Used',
        ProductItemCondition.refurbished => 'Refurbished',
        ProductItemCondition.forParts => 'For parts',
      };
}

ProductItemCondition _parseCondition(Object? value) {
  final code = '$value'.trim().toLowerCase();
  return ProductItemCondition.values.firstWhere(
    (condition) => condition.code == code,
    orElse: () => throw const FormatException(
      'Invalid HDC product condition.',
    ),
  );
}

class HdcSellingProfile {
  final String profileId;
  final HDCPlatformRole role;
  final String publicName;

  const HdcSellingProfile({
    required this.profileId,
    required this.role,
    required this.publicName,
  });

  factory HdcSellingProfile.fromJson(Map<String, dynamic> json) {
    final role = parseHDCPlatformRole(json['role']);
    if (
      role != HDCPlatformRole.seller &&
      role != HDCPlatformRole.supplier &&
      role != HDCPlatformRole.store
    ) {
      throw const FormatException('Invalid HDC selling profile.');
    }
    return HdcSellingProfile(
      profileId: '${json['profileId']}',
      role: role!,
      publicName: '${json['publicName']}',
    );
  }
}

class ProductListing {
  final String id;
  final String publicListingId;
  final String sellerProfileId;
  final String sellerUserId;
  final HDCPlatformRole sellerRole;
  final String categoryCode;
  final String title;
  final String description;
  final ProductItemCondition condition;
  final String currency;
  final int unitPriceMinor;
  final int stockQuantity;
  final ProductListingStatus status;
  final int version;
  final DateTime? publishedAt;
  final DateTime? soldAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductListing({
    required this.id,
    required this.publicListingId,
    required this.sellerProfileId,
    required this.sellerUserId,
    required this.sellerRole,
    required this.categoryCode,
    required this.title,
    required this.description,
    required this.condition,
    required this.currency,
    required this.unitPriceMinor,
    required this.stockQuantity,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.soldAt,
    this.archivedAt,
  });

  factory ProductListing.fromJson(Map<String, dynamic> json) {
    final sellerRole = parseHDCPlatformRole(json['sellerRole']);
    if (
      sellerRole != HDCPlatformRole.seller &&
      sellerRole != HDCPlatformRole.supplier &&
      sellerRole != HDCPlatformRole.store
    ) {
      throw const FormatException('Invalid HDC listing seller role.');
    }
    return ProductListing(
      id: '${json['id']}',
      publicListingId: '${json['publicListingId']}',
      sellerProfileId: '${json['sellerProfileId']}',
      sellerUserId: '${json['sellerUserId']}',
      sellerRole: sellerRole!,
      categoryCode: '${json['categoryCode']}',
      title: '${json['title']}',
      description: '${json['description']}',
      condition: _parseCondition(json['condition']),
      currency: '${json['currency']}',
      unitPriceMinor: (json['unitPriceMinor'] as num).toInt(),
      stockQuantity: (json['stockQuantity'] as num).toInt(),
      status: _parseStatus(json['status']),
      version: (json['version'] as num).toInt(),
      publishedAt: _optionalDate(json['publishedAt']),
      soldAt: _optionalDate(json['soldAt']),
      archivedAt: _optionalDate(json['archivedAt']),
      createdAt: DateTime.parse('${json['createdAt']}'),
      updatedAt: DateTime.parse('${json['updatedAt']}'),
    );
  }

  String get priceLabel {
    final whole = unitPriceMinor ~/ 100;
    final decimal = (unitPriceMinor % 100).toString().padLeft(2, '0');
    final symbol = currency == 'PHP' ? '₱' : '$currency ';
    return '$symbol$whole.$decimal';
  }

  String get categoryLabel => switch (categoryCode) {
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

  Map<String, Object?> writeBody({
    ProductListingStatus? nextStatus,
    int? nextStockQuantity,
  }) {
    return {
      'sellerRole': sellerRole.code,
      'categoryCode': categoryCode,
      'title': title,
      'description': description,
      'condition': condition.code,
      'currency': currency,
      'unitPriceMinor': unitPriceMinor,
      'stockQuantity': nextStockQuantity ?? stockQuantity,
      'status': (nextStatus ?? status).code,
      'version': version,
    };
  }
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  return DateTime.parse('$value');
}
