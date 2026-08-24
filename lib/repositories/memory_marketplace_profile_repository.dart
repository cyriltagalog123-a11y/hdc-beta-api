import '../models/marketplace_profile.dart';
import 'marketplace_profile_repository.dart';

class MemoryMarketplaceProfileRepository
    implements MarketplaceProfileRepository {

  final List<MarketplaceProfile> _profiles = [];

  @override
  List<MarketplaceProfile> getProfiles() {
    return _profiles;
  }

  @override
  Future<void> register(
    MarketplaceProfile profile,
  ) async {
    _profiles.add(profile);
  }

  @override
  Future<void> update(
    MarketplaceProfile profile,
  ) async {

    final index = _profiles.indexWhere(
      (p) => p.id == profile.id,
    );

    if (index != -1) {
      _profiles[index] = profile;
    }
  }

  @override
  Future<void> delete(
    String id,
  ) async {

    _profiles.removeWhere(
      (p) => p.id == id,
    );
  }
}