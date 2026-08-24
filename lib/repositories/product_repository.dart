import '../models/product.dart';

abstract class ProductRepository {

  List<Product> getProducts();

  Product? byId(String id);

  List<Product> byProfile(String profileId);

  Future<void> create(Product product);

  Future<void> update(Product product);

  Future<void> delete(String id);
}