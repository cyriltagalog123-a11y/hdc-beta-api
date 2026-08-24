import 'package:flutter/material.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';

class ProductProvider
    extends ChangeNotifier {

  final ProductRepository repository;

  ProductProvider({
    required this.repository,
  });

  List<Product> get products =>
      repository.getProducts();

  Product? byId(String id) =>
      repository.byId(id);

  List<Product> byProfile(
    String profileId,
  ) {

    return repository.byProfile(
      profileId,
    );
  }

  Future<void> create(
    Product product,
  ) async {

    await repository.create(product);

    notifyListeners();
  }

  Future<void> update(
    Product product,
  ) async {

    await repository.update(product);

    notifyListeners();
  }

  Future<void> delete(
    String id,
  ) async {

    await repository.delete(id);

    notifyListeners();
  }
}