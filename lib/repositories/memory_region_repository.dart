import '../models/region.dart';
import 'region_repository.dart';

class MemoryRegionRepository
    implements RegionRepository {

  final List<Region> _regions = [];

  @override
  List<Region> getRegions() {
    return _regions;
  }

  @override
  List<Region> regionsForBrand(
    String brandId,
  ) {
    return _regions
        .where(
          (r) => r.brandId == brandId,
        )
        .toList();
  }

  @override
  Future<void> registerRegion(
    Region region,
  ) async {
    _regions.add(region);
  }

  @override
  Future<void> updateRegion(
    Region region,
  ) async {
    final index = _regions.indexWhere(
      (r) => r.id == region.id,
    );

    if (index != -1) {
      _regions[index] = region;
    }
  }

  @override
  Future<void> deleteRegion(
    String regionId,
  ) async {
    _regions.removeWhere(
      (r) => r.id == regionId,
    );
  }
}