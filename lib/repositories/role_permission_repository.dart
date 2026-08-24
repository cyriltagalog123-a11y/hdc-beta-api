import '../models/role_permission.dart';

abstract class RolePermissionRepository {

  List<RolePermission> getMappings();

  List<RolePermission> forRole(
    String roleId,
  );

  Future<void> assignPermission(
    RolePermission mapping,
  );

  Future<void> removePermission(
    String mappingId,
  );
}