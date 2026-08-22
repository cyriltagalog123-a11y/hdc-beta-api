import { describe, expect, it } from 'vitest';
import {
  internalDashboardPermissions,
  internalDashboardStatisticKeys,
} from '../netlify/functions/_lib/internal-dashboard.mjs';

describe('HDC private internal dashboard permissions', () => {
  it('grants no internal capability to an ordinary account', () => {
    const permissions = internalDashboardPermissions([]);

    expect(permissions).toEqual({
      canApprovePlatformRoles: false,
      canReviewAccountRecovery: false,
      canManageInternalStructure: false,
      hasPrivilegedResourceAccess: false,
      canModerateCommunity: false,
    });
  });

  it('keeps Moderator community-scoped', () => {
    const permissions = internalDashboardPermissions(['moderator']);

    expect(permissions.canModerateCommunity).toBe(true);
    expect(permissions.canApprovePlatformRoles).toBe(false);
    expect(permissions.hasPrivilegedResourceAccess).toBe(false);
    expect(internalDashboardStatisticKeys(permissions)).toEqual([
      'myAssignments',
    ]);
  });

  it('gives Admin operational statistics without authority management', () => {
    const permissions = internalDashboardPermissions(['admin']);

    expect(permissions.hasPrivilegedResourceAccess).toBe(true);
    expect(permissions.canManageInternalStructure).toBe(false);
    expect(internalDashboardStatisticKeys(permissions)).toEqual([
      'myAssignments',
      'activeMembers',
      'openServiceRequests',
      'activeServiceTransactions',
    ]);
  });

  it('gives Owner the complete internal dashboard scope', () => {
    const permissions = internalDashboardPermissions(['owner']);
    const keys = internalDashboardStatisticKeys(permissions);

    expect(permissions.canApprovePlatformRoles).toBe(true);
    expect(permissions.canReviewAccountRecovery).toBe(true);
    expect(permissions.canManageInternalStructure).toBe(true);
    expect(permissions.hasPrivilegedResourceAccess).toBe(true);
    expect(keys).toContain('pendingRoleApplications');
    expect(keys).toContain('pendingRecoveryReviews');
    expect(keys).toContain('activeStaffAssignments');
    expect(keys).toContain('activeServiceTransactions');
  });
});
