// Legacy in-memory prototype mapping. Active authorization uses the typed,
// two-domain RolePermissionPolicy.
class RolePermission {

  final String id;

  final String roleId;

  final String permissionId;

  const RolePermission({

    required this.id,

    required this.roleId,

    required this.permissionId,
  });
}
