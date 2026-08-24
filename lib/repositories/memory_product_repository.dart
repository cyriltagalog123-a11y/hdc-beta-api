import '../models/product.dart';
import 'product_repository.dart';

class MemoryProductRepository
    implements ProductRepository {

  final List<Product> _products = [];

  @override
  List<Product> getProducts() => _products;

  @override
  Product? byId(String id) {

    try {
      return _products.firstWhere(
        (p) => p.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  List<Product> byProfile(
    String profileId,
  ) {

    return _products.where(
      (p) =>
          p.profileId ==
          profileId,
    ).toList();
  }

  @override
  Future<void> create(
    Product product,
  ) async {

    _products.add(product);
  }

  @override
  Future<void> update(
    Product product,
  ) async {

    final index =
        _products.indexWhere(
      (p) => p.id == product.id,
    );

    if (index != -1) {
      _products[index] = product;
    }
  }

  @override
  Future<void> delete(
    String id,
  ) async {

    _products.removeWhere(
      (p) => p.id == id,
    );
  }
}