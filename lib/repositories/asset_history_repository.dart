import '../data/datasources/asset_history_memory_datasource.dart';
import '../models/asset_history.dart';

class AssetHistoryRepository {
  AssetHistoryRepository._();

  static final AssetHistoryRepository instance =
      AssetHistoryRepository._();

  final AssetHistoryMemoryDataSource _dataSource =
      AssetHistoryMemoryDataSource.instance;

  List<AssetHistory> getAssetHistory(
    String assetId,
  ) {
    return _dataSource.getAssetEvents(assetId);
  }

  void addEvent(AssetHistory event) {
    _dataSource.addEvent(event);
  }

  void clear() {
    _dataSource.clear();
  }
}