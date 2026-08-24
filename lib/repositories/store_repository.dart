import '../models/store.dart';

abstract class StoreRepository {

  List<Store> getStores();

  List<Store> storesForRegion(
    String regionId,
  );

  Future<void> registerStore(
    Store store,
  );

  Future<void> updateStore(
    Store store,
  );

  Future<void> deleteStore(
    String storeId,
  );
}