import '../../models/account_identity.dart';
import 'hdc_permission.dart';
import 'role_permission_policy.dart';

class AuthorizationService {
  final RolePermissionPolicy policy;

  const AuthorizationService({
    this.policy = const RolePermissionPolicy(),
  });

  void requirePermission({
    required AccountIdentity identity,
    required HDCPermission permission,
  }) {
    if (!identity.isActive) {
      throw StateError('Inactive accounts cannot perform this action.');
    }

    if (!policy.can(
      platformRoles: identity.platformRoles,
      internalRoles: identity.internalRoles,
      permission: permission,
    )) {
      throw StateError(
        'This HDC account is not authorized for ${permission.name}.',
      );
    }
  }

  void requireResourceOwner({
    required AccountIdentity identity,
    required String ownerUserId,
  }) {
    if (identity.id != ownerUserId && !identity.hasPrivilegedRole) {
      throw StateError('This HDC account does not own this resource.');
    }
  }

  void requireTransactionParticipant({
    required AccountIdentity identity,
    required String customerId,
    required String technicianId,
  }) {
    if (identity.id != customerId &&
        identity.id != technicianId &&
        !identity.hasPrivilegedRole) {
      throw StateError(
        'This HDC account is not a participant in this transaction.',
      );
    }
  }
}
