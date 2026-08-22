import {
  canApprovePlatformRoles,
  canManageInternalStructure,
  hasPrivilegedResourceAccess,
  type InternalRoleCode,
} from './roles.mjs';

export type InternalDashboardPermissions = {
  canApprovePlatformRoles: boolean;
  canReviewAccountRecovery: boolean;
  canManageInternalStructure: boolean;
  hasPrivilegedResourceAccess: boolean;
  canModerateCommunity: boolean;
};

export type InternalDashboardStatisticKey =
  | 'myAssignments'
  | 'pendingRoleApplications'
  | 'pendingRecoveryReviews'
  | 'activeDepartments'
  | 'activeSections'
  | 'activeStaffAssignments'
  | 'activeMembers'
  | 'openServiceRequests'
  | 'activeServiceTransactions';

export function internalDashboardPermissions(
  roles: Iterable<InternalRoleCode>,
): InternalDashboardPermissions {
  const values = [...roles];
  return {
    canApprovePlatformRoles: canApprovePlatformRoles(values),
    canReviewAccountRecovery: canApprovePlatformRoles(values),
    canManageInternalStructure: canManageInternalStructure(values),
    hasPrivilegedResourceAccess: hasPrivilegedResourceAccess(values),
    canModerateCommunity: values.length > 0,
  };
}

export function internalDashboardStatisticKeys(
  permissions: InternalDashboardPermissions,
): InternalDashboardStatisticKey[] {
  const keys: InternalDashboardStatisticKey[] = ['myAssignments'];
  if (permissions.canApprovePlatformRoles) {
    keys.push('pendingRoleApplications');
  }
  if (permissions.canReviewAccountRecovery) {
    keys.push('pendingRecoveryReviews');
  }
  if (permissions.canManageInternalStructure) {
    keys.push(
      'activeDepartments',
      'activeSections',
      'activeStaffAssignments',
    );
  }
  if (permissions.hasPrivilegedResourceAccess) {
    keys.push(
      'activeMembers',
      'openServiceRequests',
      'activeServiceTransactions',
    );
  }
  return keys;
}
