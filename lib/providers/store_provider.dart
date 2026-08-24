import 'package:flutter/material.dart';

import '../models/store.dart';
import '../repositories/store_repository.dart';

class StoreProvider
    extends ChangeNotifier {

  final StoreRepository repository;

  StoreProvider({
    required this.repository,
  });

  List<Store> get stores =>
      repository.getStores();

  List<Store> forRegion(
    String regionId,
  ) {
    return repository.storesForRegion(
      regionId,
    );
  }

  Future<void> registerStore(
    Store store,
  ) async {

    await repository.registerStore(
      store,
    );

    notifyListeners();
  }

  Future<void> updateStore(
    Store store,
  ) async {

    await repository.updateStore(
      store,
    );

    notifyListeners();
  }

  Future<void> deleteStore(
    String id,
  ) async {

    await repository.deleteStore(id);

    notifyListeners();
  }
}