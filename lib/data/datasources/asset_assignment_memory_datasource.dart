import '../../models/asset_assignment.dart';

class AssetAssignmentMemoryDataSource {
  AssetAssignmentMemoryDataSource._();

  static final AssetAssignmentMemoryDataSource instance =
      AssetAssignmentMemoryDataSource._();

  final List<AssetAssignment> _assignments = [];

  List<AssetAssignment> getAllAssignments() {
    return List.unmodifiable(_assignments);
  }

  List<AssetAssignment> getAssignmentsForAsset(
    String assetId,
  ) {
    return _assignments
        .where((assignment) => assignment.assetId == assetId)
        .toList();
  }

  AssetAssignment? getCurrentAssignment(
    String assetId,
  ) {
    try {
      return _assignments.lastWhere(
        (assignment) =>
            assignment.assetId == assetId &&
            assignment.status ==
                AssetAssignmentStatus.active,
      );
    } catch (_) {
      return null;
    }
  }

  void addAssignment(
    AssetAssignment assignment,
  ) {
    _assignments.add(assignment);
  }

  void clear() {
    _assignments.clear();
  }
}