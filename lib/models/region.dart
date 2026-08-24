class Region {
  final String id;

  final String organizationId;

  final String brandId;

  final String name;

  final String code;

  final String description;

  final bool active;

  const Region({
    required this.id,
    required this.organizationId,
    required this.brandId,
    required this.name,
    required this.code,
    required this.description,
    required this.active,
  });
}