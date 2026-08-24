import '../../models/organization.dart';

class OrganizationMemoryDataSource {
  OrganizationMemoryDataSource._();

  static final OrganizationMemoryDataSource instance =
      OrganizationMemoryDataSource._();

  final List<Organization> _organizations = [];

  List<Organization> getAllOrganizations() {
    return List.unmodifiable(_organizations);
  }

  Organization? getOrganization(String id) {
    try {
      return _organizations.firstWhere(
        (organization) => organization.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  void addOrganization(
    Organization organization,
  ) {
    _organizations.add(organization);
  }

  void clear() {
    _organizations.clear();
  }
}