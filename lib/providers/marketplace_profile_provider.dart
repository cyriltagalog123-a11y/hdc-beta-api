import 'package:flutter/material.dart';

import '../models/marketplace_profile.dart';
import '../repositories/marketplace_profile_repository.dart';

class MarketplaceProfileProvider
    extends ChangeNotifier {

  final MarketplaceProfileRepository repository;

  MarketplaceProfileProvider({
    required this.repository,
  });

  List<MarketplaceProfile> get profiles =>
      repository.getProfiles();

  Future<void> register(
    MarketplaceProfile profile,
  ) async {

    await repository.register(profile);

    notifyListeners();
  }

  Future<void> update(
    MarketplaceProfile profile,
  ) async {

    await repository.update(profile);

    notifyListeners();
  }

  Future<void> delete(
    String id,
  ) async {

    await repository.delete(id);

    notifyListeners();
  }
}