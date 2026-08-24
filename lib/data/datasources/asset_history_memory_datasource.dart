import '../../models/asset_history.dart';

class AssetHistoryMemoryDataSource {
  AssetHistoryMemoryDataSource._();

  static final AssetHistoryMemoryDataSource instance =
      AssetHistoryMemoryDataSource._();

  final List<AssetHistory> _events = [];

  List<AssetHistory> getAllEvents() {
    return List.unmodifiable(_events);
  }

  List<AssetHistory> getAssetEvents(String assetId) {
    return _events
        .where((event) => event.assetId == assetId)
        .toList()
      ..sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );
  }

  void addEvent(AssetHistory event) {
    _events.add(event);
  }

  void clear() {
    _events.clear();
  }
}