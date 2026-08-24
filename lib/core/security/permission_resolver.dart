import '../../models/permission.dart';
import '../../providers/role_permission_provider.dart';
import '../../providers/user_role_provider.dart';

// Legacy prototype resolver retained for compatibility only. It is not wired
// into HDC authentication or the platform/internal role boundary.
class PermissionResolver {

  final UserRoleProvider userRoles;

  final RolePermissionProvider rolePermissions;

  final List<Permission> permissions;

  PermissionResolver({

    required this.userRoles,

    required this.rolePermissions,

    required this.permissions,
  });

  bool can({

    required String userAccountId,

    required String permissionCode,

  }) {

    final assignedRoles =
        userRoles.forUser(userAccountId);

    for (final role in assignedRoles) {

      final mappings =
          rolePermissions.forRole(role.roleId);

      for (final mapping in mappings) {

        final permission =
            permissions.firstWhere(

          (p) =>
              p.id ==
              mapping.permissionId,

          orElse: () => const Permission(
            id: "",
            code: "",
            description: "",
          ),
        );

        if (permission.code == permissionCode) {
          return true;
        }
      }
    }

    return false;
  }
}
