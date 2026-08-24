import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../repositories/asset_repository.dart';

class AssetProvider extends ChangeNotifier {
  final AssetRepository _repository =
      AssetRepository.instance;

  List<Asset> _assets = [];

  List<Asset> get assets =>
      List.unmodifiable(_assets);

  AssetProvider() {
    loadAssets();
  }

  void loadAssets() {
    _assets = _repository.getAllAssets();
    notifyListeners();
  }

  Asset? findAsset(String id) {
    try {
      return _assets.firstWhere(
        (asset) => asset.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  void registerAsset(Asset asset) {
    _repository.registerAsset(asset);

    loadAssets();
  }

  void updateAsset(Asset asset) {
    _repository.updateAsset(asset);

    loadAssets();
  }

  void removeAsset(String id) {
    _repository.removeAsset(id);

    loadAssets();
  }

  void clearAssets() {
    _repository.clearAssets();

    loadAssets();
  }
}