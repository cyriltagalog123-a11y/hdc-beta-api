import 'package:flutter/material.dart';

import '../models/role_permission.dart';
import '../repositories/role_permission_repository.dart';

class RolePermissionProvider
    extends ChangeNotifier {

  final RolePermissionRepository repository;

  RolePermissionProvider({
    required this.repository,
  });

  List<RolePermission> get mappings =>
      repository.getMappings();

  List<RolePermission> forRole(
    String roleId,
  ) {
    return repository.forRole(
      roleId,
    );
  }

  Future<void> assignPermission(
    RolePermission mapping,
  ) async {

    await repository.assignPermission(
      mapping);

    notifyListeners();
  }

  Future<void> removePermission(
    String id,
  ) async {

    await repository.removePermission(id);

    notifyListeners();
  }
}