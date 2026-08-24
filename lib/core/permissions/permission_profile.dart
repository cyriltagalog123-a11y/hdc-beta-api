import 'app_permission.dart';

class PermissionProfile {
  final String id;

  final String name;

  final Set<AppPermission> permissions;

  const PermissionProfile({
    required this.id,
    required this.name,
    required this.permissions,
  });

  bool hasPermission(
    AppPermission permission,
  ) {
    return permissions.contains(permission);
  }
}