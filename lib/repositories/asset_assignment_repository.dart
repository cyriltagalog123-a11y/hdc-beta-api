import '../data/datasources/asset_assignment_memory_datasource.dart';
import '../models/asset_assignment.dart';

class AssetAssignmentRepository {
  AssetAssignmentRepository._();

  static final AssetAssignmentRepository instance =
      AssetAssignmentRepository._();

  final AssetAssignmentMemoryDataSource _dataSource =
      AssetAssignmentMemoryDataSource.instance;

  List<AssetAssignment> getAssignments(
    String assetId,
  ) {
    return _dataSource.getAssignmentsForAsset(
      assetId,
    );
  }

  AssetAssignment? currentAssignment(
    String assetId,
  ) {
    return _dataSource.getCurrentAssignment(
      assetId,
    );
  }

  void assign(
    AssetAssignment assignment,
  ) {
    _dataSource.addAssignment(
      assignment,
    );
  }

  void clear() {
    _dataSource.clear();
  }
}