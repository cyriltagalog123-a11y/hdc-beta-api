import 'package:flutter_test/flutter_test.dart';

import 'package:hdc_app/core/security/hdc_permission.dart';
import 'package:hdc_app/core/security/role_permission_policy.dart';
import 'package:hdc_app/models/account_identity.dart';

void main() {
  const policy = RolePermissionPolicy();

  test('platform roles never imply internal administration', () {
    final permissions = policy.permissionsFor(
      platformRoles: const {
        HDCPlatformRole.customer,
        HDCPlatformRole.technician,
        HDCPlatformRole.business,
      },
    );

    expect(permissions, contains(HDCPermission.requestCreate));
    expect(permissions, contains(HDCPermission.proposalCreate));
    expect(permissions, isNot(contains(HDCPermission.adminRead)));
    expect(
      permissions,
      isNot(contains(HDCPermission.internalRoleApplicationsReview)),
    );
  });

  test('Supplier receives marketplace capabilities without internal authority', () {
    final permissions = policy.permissionsFor(
      platformRoles: const {HDCPlatformRole.supplier},
    );

    expect(permissions, contains(HDCPermission.marketplaceSell));
    expect(permissions, isNot(contains(HDCPermission.adminManageAccounts)));
  });

  test('Moderator remains community-scoped', () {
    final permissions = policy.permissionsFor(
      platformRoles: const {HDCPlatformRole.customer},
      internalRoles: const {HDCInternalRole.moderator},
    );

    expect(permissions, contains(HDCPermission.communityModerate));
    expect(permissions, isNot(contains(HDCPermission.adminManageAccounts)));
    expect(
      permissions,
      isNot(contains(HDCPermission.internalStructureManage)),
    );
  });

  test('only Owner and Super Admin can approve platform roles', () {
    expect(HDCInternalRole.owner.canApprovePlatformRoles, isTrue);
    expect(HDCInternalRole.superAdmin.canApprovePlatformRoles, isTrue);
    expect(HDCInternalRole.admin.canApprovePlatformRoles, isFalse);
    expect(HDCInternalRole.moderator.canApprovePlatformRoles, isFalse);
  });

  test('resource override excludes Moderator', () {
    final now = DateTime(2026, 8, 21);
    final moderator = AccountIdentity(
      id: 'moderator-1',
      displayName: 'Moderator',
      status: HDCAccountStatus.active,
      platformRoles: const {HDCPlatformRole.customer},
      internalRoles: const {HDCInternalRole.moderator},
      createdAt: now,
      updatedAt: now,
    );
    final admin = moderator.copyWith(
      internalRoles: const {HDCInternalRole.admin},
    );

    expect(moderator.hasPrivilegedRole, isFalse);
    expect(admin.hasPrivilegedRole, isTrue);
  });
}
