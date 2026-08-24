import '../models/role_permission.dart';
import 'role_permission_repository.dart';

class MemoryRolePermissionRepository
    implements RolePermissionRepository {

  final List<RolePermission> _mappings = [];

  @override
  List<RolePermission> getMappings() =>
      _mappings;

  @override
  List<RolePermission> forRole(
    String roleId,
  ) {

    return _mappings
        .where(
          (m) =>
              m.roleId ==
              roleId,
        )
        .toList();
  }

  @override
  Future<void> assignPermission(
    RolePermission mapping,
  ) async {

    _mappings.add(mapping);
  }

  @override
  Future<void> removePermission(
    String mappingId,
  ) async {

    _mappings.removeWhere(
      (m) =>
          m.id ==
          mappingId,
    );
  }
}