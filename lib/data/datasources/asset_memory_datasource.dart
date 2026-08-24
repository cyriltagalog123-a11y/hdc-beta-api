import '../../models/asset.dart';

class AssetMemoryDataSource {
  AssetMemoryDataSource._();

  static final AssetMemoryDataSource instance =
      AssetMemoryDataSource._();

  final List<Asset> _assets = [];

  List<Asset> getAllAssets() {
    return List.unmodifiable(_assets);
  }

  void addAsset(Asset asset) {
    _assets.add(asset);
  }

  Asset? findAsset(String assetId) {
    try {
      return _assets.firstWhere(
        (asset) => asset.id == assetId,
      );
    } catch (_) {
      return null;
    }
  }

  void updateAsset(Asset updatedAsset) {
    final index = _assets.indexWhere(
      (asset) => asset.id == updatedAsset.id,
    );

    if (index == -1) return;

    _assets[index] = updatedAsset;
  }

  void removeAsset(String assetId) {
    _assets.removeWhere(
      (asset) => asset.id == assetId,
    );
  }

  void clear() {
    _assets.clear();
  }
}