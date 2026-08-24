import '../models/store.dart';
import 'store_repository.dart';

class MemoryStoreRepository
    implements StoreRepository {

  final List<Store> _stores = [];

  @override
  List<Store> getStores() {
    return _stores;
  }

  @override
  List<Store> storesForRegion(
    String regionId,
  ) {
    return _stores
        .where(
          (store) =>
              store.regionId == regionId,
        )
        .toList();
  }

  @override
  Future<void> registerStore(
    Store store,
  ) async {
    _stores.add(store);
  }

  @override
  Future<void> updateStore(
    Store store,
  ) async {

    final index =
        _stores.indexWhere(
      (s) => s.id == store.id,
    );

    if (index != -1) {
      _stores[index] = store;
    }
  }

  @override
  Future<void> deleteStore(
    String storeId,
  ) async {
    _stores.removeWhere(
      (s) => s.id == storeId,
    );
  }
}