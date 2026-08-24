class Store {
  final String id;

  final String organizationId;

  final String brandId;

  final String regionId;

  final String name;

  final String storeNumber;

  final String address;

  final bool active;

  const Store({
    required this.id,
    required this.organizationId,
    required this.brandId,
    required this.regionId,
    required this.name,
    required this.storeNumber,
    required this.address,
    required this.active,
  });
}