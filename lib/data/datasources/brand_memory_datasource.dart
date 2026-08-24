import '../../models/brand.dart';

class BrandMemoryDataSource {
  BrandMemoryDataSource._();

  static final BrandMemoryDataSource instance =
      BrandMemoryDataSource._();

  final List<Brand> _brands = [];

  List<Brand> getBrands(
    String organizationId,
  ) {
    return _brands
        .where(
          (brand) =>
              brand.organizationId ==
              organizationId,
        )
        .toList();
  }

  void addBrand(
    Brand brand,
  ) {
    _brands.add(brand);
  }

  void clear() {
    _brands.clear();
  }
}