import '../models/marketplace_profile.dart';

abstract class MarketplaceProfileRepository {

  List<MarketplaceProfile> getProfiles();

  Future<void> register(
    MarketplaceProfile profile,
  );

  Future<void> update(
    MarketplaceProfile profile,
  );

  Future<void> delete(
    String id,
  );
}