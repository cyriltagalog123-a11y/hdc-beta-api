import '../data/datasources/brand_memory_datasource.dart';
import '../models/brand.dart';

class BrandRepository {
  BrandRepository._();

  static final BrandRepository instance =
      BrandRepository._();

  final BrandMemoryDataSource _dataSource =
      BrandMemoryDataSource.instance;

  List<Brand> getBrands(
    String organizationId,
  ) {
    return _dataSource.getBrands(
      organizationId,
    );
  }

  void registerBrand(
    Brand brand,
  ) {
    _dataSource.addBrand(
      brand,
    );
  }

  void clear() {
    _dataSource.clear();
  }
}