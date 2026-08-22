export const PLATFORM_ROLE_CODES = [
  'customer',
  'technician',
  'seller',
  'business',
  'supplier',
  'store',
] as const;

export const APPROVAL_PLATFORM_ROLE_CODES = [
  'technician',
  'business',
  'seller',
  'supplier',
  // Kept for compatibility with the existing HDC Store workspace.
  'store',
] as const;

export const INTERNAL_ROLE_CODES = [
  'owner',
  'super_admin',
  'admin',
  'moderator',
] as const;

export type PlatformRoleCode = typeof PLATFORM_ROLE_CODES[number];
export type ApprovalPlatformRoleCode = typeof APPROVAL_PLATFORM_ROLE_CODES[number];
export type InternalRoleCode = typeof INTERNAL_ROLE_CODES[number];

const platformRoleSet = new Set<string>(PLATFORM_ROLE_CODES);
const approvalPlatformRoleSet = new Set<string>(APPROVAL_PLATFORM_ROLE_CODES);
const internalRoleSet = new Set<string>(INTERNAL_ROLE_CODES);

export type SplitRoleCodes = {
  platformRoles: PlatformRoleCode[];
  internalRoles: InternalRoleCode[];
};

export function normalizeRoleCode(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toLowerCase().replaceAll('-', '_');
  if (!normalized) return null;
  if (normalized === 'superadmin') return 'super_admin';
  return normalized;
}

export function isPlatformRoleCode(value: unknown): value is PlatformRoleCode {
  const normalized = normalizeRoleCode(value);
  return normalized !== null && platformRoleSet.has(normalized);
}

export function isApprovalPlatformRoleCode(
  value: unknown,
): value is ApprovalPlatformRoleCode {
  const normalized = normalizeRoleCode(value);
  return normalized !== null && approvalPlatformRoleSet.has(normalized);
}

export function isInternalRoleCode(value: unknown): value is InternalRoleCode {
  const normalized = normalizeRoleCode(value);
  return normalized !== null && internalRoleSet.has(normalized);
}

export function splitRoleCodes(values: Iterable<unknown>): SplitRoleCodes {
  const platformRoles = new Set<PlatformRoleCode>();
  const internalRoles = new Set<InternalRoleCode>();

  for (const value of values) {
    const normalized = normalizeRoleCode(value);
    if (!normalized) continue;
    if (platformRoleSet.has(normalized)) {
      platformRoles.add(normalized as PlatformRoleCode);
    } else if (internalRoleSet.has(normalized)) {
      internalRoles.add(normalized as InternalRoleCode);
    }
  }

  return {
    platformRoles: [...platformRoles].sort(),
    internalRoles: [...internalRoles].sort(),
  };
}

export function canApprovePlatformRoles(roles: Iterable<InternalRoleCode>): boolean {
  for (const role of roles) {
    if (role === 'owner' || role === 'super_admin') return true;
  }
  return false;
}

export function canManageInternalStructure(roles: Iterable<InternalRoleCode>): boolean {
  return canApprovePlatformRoles(roles);
}

export function hasPrivilegedResourceAccess(roles: Iterable<InternalRoleCode>): boolean {
  for (const role of roles) {
    if (role === 'owner' || role === 'super_admin' || role === 'admin') {
      return true;
    }
  }
  return false;
}

export function normalizeRoleApplicationNote(value: unknown): string | null {
  if (value === undefined || value === null) return '';
  if (typeof value !== 'string') return null;
  const note = value.trim().replace(/\s+/g, ' ');
  if (note.length > 1000) return null;
  return note;
}

