import 'package:flutter/material.dart';

import '../models/region.dart';
import '../repositories/region_repository.dart';

class RegionProvider
    extends ChangeNotifier {

  final RegionRepository repository;

  RegionProvider({
    required this.repository,
  });

  List<Region> get regions =>
      repository.getRegions();

  List<Region> forBrand(
    String brandId,
  ) {
    return repository.regionsForBrand(
      brandId,
    );
  }

  Future<void> registerRegion(
    Region region,
  ) async {
    await repository.registerRegion(
      region,
    );

    notifyListeners();
  }

  Future<void> updateRegion(
    Region region,
  ) async {
    await repository.updateRegion(
      region,
    );

    notifyListeners();
  }

  Future<void> deleteRegion(
    String id,
  ) async {
    await repository.deleteRegion(id);

    notifyListeners();
  }
}