import '../../models/account_identity.dart';
import 'hdc_permission.dart';

/// Resolves permissions from two intentionally separate role domains.
///
/// Platform roles grant product capabilities. Internal roles grant private HDC
/// operational authority. An elevated platform role can never imply internal
/// administrative access.
class RolePermissionPolicy {
  const RolePermissionPolicy();

  Set<HDCPermission> permissionsFor({
    required Set<HDCPlatformRole> platformRoles,
    Set<HDCInternalRole> internalRoles = const <HDCInternalRole>{},
  }) {
    final permissions = <HDCPermission>{};

    for (final role in platformRoles) {
      permissions.addAll(_forPlatformRole(role));
    }
    for (final role in internalRoles) {
      permissions.addAll(_forInternalRole(role));
    }

    return permissions;
  }

  bool can({
    required Set<HDCPlatformRole> platformRoles,
    required Set<HDCInternalRole> internalRoles,
    required HDCPermission permission,
  }) {
    return permissionsFor(
      platformRoles: platformRoles,
      internalRoles: internalRoles,
    ).contains(permission);
  }

  Set<HDCPermission> _forPlatformRole(HDCPlatformRole role) {
    switch (role) {
      case HDCPlatformRole.customer:
        return const {
          HDCPermission.requestCreate,
          HDCPermission.requestReadOwn,
          HDCPermission.requestEditOwn,
          HDCPermission.requestCancelOwn,
          HDCPermission.proposalAcceptOwnRequest,
          HDCPermission.transactionReadOwn,
          HDCPermission.transactionUpdateOwn,
          HDCPermission.transactionCompleteOwn,
          HDCPermission.privateMessageReadOwnTransaction,
          HDCPermission.privateMessageSendOwnTransaction,
          HDCPermission.marketplaceBrowse,
          HDCPermission.roleApplicationSubmit,
        };

      case HDCPlatformRole.technician:
        return const {
          HDCPermission.proposalCreate,
          HDCPermission.proposalReadOwn,
          HDCPermission.transactionReadOwn,
          HDCPermission.transactionUpdateOwn,
          HDCPermission.privateMessageReadOwnTransaction,
          HDCPermission.privateMessageSendOwnTransaction,
          HDCPermission.marketplaceBrowse,
        };

      case HDCPlatformRole.seller:
      case HDCPlatformRole.supplier:
        return const {
          HDCPermission.marketplaceBrowse,
          HDCPermission.marketplaceSell,
          HDCPermission.privateMessageReadOwnTransaction,
          HDCPermission.privateMessageSendOwnTransaction,
        };

      case HDCPlatformRole.business:
        return const {
          HDCPermission.requestCreate,
          HDCPermission.requestReadOwn,
          HDCPermission.requestEditOwn,
          HDCPermission.requestCancelOwn,
          HDCPermission.proposalAcceptOwnRequest,
          HDCPermission.transactionReadOwn,
          HDCPermission.transactionUpdateOwn,
          HDCPermission.transactionCompleteOwn,
          HDCPermission.privateMessageReadOwnTransaction,
          HDCPermission.privateMessageSendOwnTransaction,
          HDCPermission.marketplaceBrowse,
          HDCPermission.businessManageOwn,
        };

      case HDCPlatformRole.store:
        return const {
          HDCPermission.requestCreate,
          HDCPermission.requestReadOwn,
          HDCPermission.requestEditOwn,
          HDCPermission.requestCancelOwn,
          HDCPermission.proposalAcceptOwnRequest,
          HDCPermission.transactionReadOwn,
          HDCPermission.transactionUpdateOwn,
          HDCPermission.transactionCompleteOwn,
          HDCPermission.privateMessageReadOwnTransaction,
          HDCPermission.privateMessageSendOwnTransaction,
          HDCPermission.marketplaceBrowse,
          HDCPermission.storeManageOwn,
        };
    }
  }

  Set<HDCPermission> _forInternalRole(HDCInternalRole role) {
    switch (role) {
      case HDCInternalRole.owner:
      case HDCInternalRole.superAdmin:
        return HDCPermission.values.toSet();

      case HDCInternalRole.admin:
        return const {
          HDCPermission.adminRead,
          HDCPermission.adminManageAccounts,
          HDCPermission.communityModerate,
        };

      case HDCInternalRole.moderator:
        return const {
          HDCPermission.communityModerate,
        };
    }
  }
}
