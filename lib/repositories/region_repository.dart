import '../models/region.dart';

abstract class RegionRepository {
  List<Region> getRegions();

  List<Region> regionsForBrand(
    String brandId,
  );

  Future<void> registerRegion(
    Region region,
  );

  Future<void> updateRegion(
    Region region,
  );

  Future<void> deleteRegion(
    String regionId,
  );
}