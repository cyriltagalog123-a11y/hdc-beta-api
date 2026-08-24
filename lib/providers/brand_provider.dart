import 'package:flutter/material.dart';

import '../models/brand.dart';
import '../repositories/brand_repository.dart';

class BrandProvider
    extends ChangeNotifier {
  final BrandRepository _repository =
      BrandRepository.instance;

  List<Brand> brands(
    String organizationId,
  ) {
    return _repository.getBrands(
      organizationId,
    );
  }

  void registerBrand(
    Brand brand,
  ) {
    _repository.registerBrand(
      brand,
    );

    notifyListeners();
  }

  void clear() {
    _repository.clear();

    notifyListeners();
  }
}