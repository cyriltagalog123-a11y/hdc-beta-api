import 'package:flutter/material.dart';

import '../models/organization.dart';
import '../repositories/organization_repository.dart';

class OrganizationProvider
    extends ChangeNotifier {
  final OrganizationRepository _repository =
      OrganizationRepository.instance;

  List<Organization> get organizations =>
      _repository.getOrganizations();

  Organization? findOrganization(
    String id,
  ) {
    return _repository.getOrganization(id);
  }

  void registerOrganization(
    Organization organization,
  ) {
    _repository.registerOrganization(
      organization,
    );

    notifyListeners();
  }

  void clear() {
    _repository.clear();

    notifyListeners();
  }
}