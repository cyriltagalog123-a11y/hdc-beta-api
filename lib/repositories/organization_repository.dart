import '../data/datasources/organization_memory_datasource.dart';
import '../models/organization.dart';

class OrganizationRepository {
  OrganizationRepository._();

  static final OrganizationRepository instance =
      OrganizationRepository._();

  final OrganizationMemoryDataSource _dataSource =
      OrganizationMemoryDataSource.instance;

  List<Organization> getOrganizations() {
    return _dataSource.getAllOrganizations();
  }

  Organization? getOrganization(
    String id,
  ) {
    return _dataSource.getOrganization(id);
  }

  void registerOrganization(
    Organization organization,
  ) {
    _dataSource.addOrganization(
      organization,
    );
  }

  void clear() {
    _dataSource.clear();
  }
}