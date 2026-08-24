import '../data/datasources/asset_memory_datasource.dart';
import '../models/asset.dart';

class AssetRepository {
  AssetRepository._();

  static final AssetRepository instance =
      AssetRepository._();

  final AssetMemoryDataSource _dataSource =
      AssetMemoryDataSource.instance;

  List<Asset> getAllAssets() {
    return _dataSource.getAllAssets();
  }

  Asset? findAsset(String id) {
    return _dataSource.findAsset(id);
  }

  void registerAsset(Asset asset) {
    _dataSource.addAsset(asset);
  }

  void updateAsset(Asset asset) {
    _dataSource.updateAsset(asset);
  }

  void removeAsset(String id) {
    _dataSource.removeAsset(id);
  }

  void clearAssets() {
    _dataSource.clear();
  }
}