import 'app_permission.dart';
import 'permission_profile.dart';

class PermissionEngine {
  PermissionEngine._();

  static final PermissionEngine instance =
      PermissionEngine._();

  PermissionProfile? currentProfile;

  bool can(
    AppPermission permission,
  ) {
    if (currentProfile == null) {
      return false;
    }

    return currentProfile!
        .hasPermission(permission);
  }
}