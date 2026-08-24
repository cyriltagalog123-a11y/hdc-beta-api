import 'package:flutter/material.dart';

import '../models/supplier.dart';
import '../repositories/supplier_repository.dart';

class SupplierProvider extends ChangeNotifier {

  final SupplierRepository repository;

  SupplierProvider({
    required this.repository,
  });

  List<Supplier> get suppliers =>
      repository.getSuppliers();

  Supplier? byId(String id) =>
      repository.byId(id);

  Future<void> create(
    Supplier supplier,
  ) async {

    await repository.create(supplier);

    notifyListeners();
  }

  Future<void> update(
    Supplier supplier,
  ) async {

    await repository.update(supplier);

    notifyListeners();
  }

  Future<void> delete(
    String id,
  ) async {

    await repository.delete(id);

    notifyListeners();
  }
}