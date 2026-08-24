import '../models/supplier.dart';

abstract class SupplierRepository {

  List<Supplier> getSuppliers();

  Supplier? byId(String id);

  Future<void> create(
    Supplier supplier,
  );

  Future<void> update(
    Supplier supplier,
  );

  Future<void> delete(
    String id,
  );
}