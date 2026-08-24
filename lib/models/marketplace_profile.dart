enum MarketplaceType {

  seller,

  supplier,

  serviceProvider,
}

class MarketplaceProfile {

  final String id;

  final String organizationId;

  final MarketplaceType type;

  final String businessName;

  final String contactPerson;

  final String email;

  final String phone;

  final bool verified;

  const MarketplaceProfile({

    required this.id,

    required this.organizationId,

    required this.type,

    required this.businessName,

    required this.contactPerson,

    required this.email,

    required this.phone,

    required this.verified,
  });
}