import 'package:flutter/material.dart';

import '../models/asset_history.dart';
import '../repositories/asset_history_repository.dart';

class AssetHistoryProvider extends ChangeNotifier {
  final AssetHistoryRepository _repository =
      AssetHistoryRepository.instance;

  List<AssetHistory> getHistory(
    String assetId,
  ) {
    return _repository.getAssetHistory(assetId);
  }

  void addEvent(
    AssetHistory event,
  ) {
    _repository.addEvent(event);

    notifyListeners();
  }

  void clear() {
    _repository.clear();

    notifyListeners();
  }
}