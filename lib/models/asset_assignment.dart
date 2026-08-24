enum AssetAssignmentStatus {
  active,
  transferred,
  returned,
  retired,
}

class AssetAssignment {
  final String id;

  final String assetId;

  final String organizationId;

  final String brandId;

  final String regionId;

  final String storeId;

  final String departmentId;

  final String assignedTo;

  final DateTime assignedDate;

  final DateTime? releasedDate;

  final AssetAssignmentStatus status;

  const AssetAssignment({
    required this.id,
    required this.assetId,
    required this.organizationId,
    required this.brandId,
    required this.regionId,
    required this.storeId,
    required this.departmentId,
    required this.assignedTo,
    required this.assignedDate,
    required this.status,
    this.releasedDate,
  });
}