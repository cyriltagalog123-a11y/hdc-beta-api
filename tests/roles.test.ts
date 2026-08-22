import { describe, expect, it } from 'vitest';
import {
  APPROVAL_PLATFORM_ROLE_CODES,
  INTERNAL_ROLE_CODES,
  PLATFORM_ROLE_CODES,
  canApprovePlatformRoles,
  canManageInternalStructure,
  hasPrivilegedResourceAccess,
  isApprovalPlatformRoleCode,
  normalizeRoleApplicationNote,
  splitRoleCodes,
} from '../netlify/functions/_lib/roles.mjs';
import {
  ROLE_APPLICATION_FORM_VERSION,
  normalizeRoleApplicationAnswers,
} from '../netlify/functions/_lib/role-applications.mjs';

describe('HDC role domains', () => {
  it('keeps platform and internal roles in separate code sets', () => {
    expect(PLATFORM_ROLE_CODES).toContain('technician');
    expect(PLATFORM_ROLE_CODES).toContain('supplier');
    expect(PLATFORM_ROLE_CODES).not.toContain('admin' as never);
    expect(INTERNAL_ROLE_CODES).toContain('admin');
    expect(INTERNAL_ROLE_CODES).not.toContain('technician' as never);
  });

  it('splits a legacy mixed role list without trusting unknown values', () => {
    expect(splitRoleCodes([
      'customer',
      'technician',
      'superAdmin',
      'admin',
      'invented_role',
      'customer',
    ])).toEqual({
      platformRoles: ['customer', 'technician'],
      internalRoles: ['admin', 'super_admin'],
    });
  });

  it('requires approval for every elevated platform workspace', () => {
    expect(APPROVAL_PLATFORM_ROLE_CODES).toEqual([
      'technician',
      'business',
      'seller',
      'supplier',
      'store',
    ]);
    expect(isApprovalPlatformRoleCode('customer')).toBe(false);
    expect(isApprovalPlatformRoleCode('supplier')).toBe(true);
  });

  it('limits role approvals and internal structure changes to Owner or Super Admin', () => {
    expect(canApprovePlatformRoles(['owner'])).toBe(true);
    expect(canApprovePlatformRoles(['super_admin'])).toBe(true);
    expect(canApprovePlatformRoles(['admin'])).toBe(false);
    expect(canApprovePlatformRoles(['moderator'])).toBe(false);
    expect(canManageInternalStructure(['admin'])).toBe(false);
  });

  it('does not grant Moderator a privileged resource override', () => {
    expect(hasPrivilegedResourceAccess(['admin'])).toBe(true);
    expect(hasPrivilegedResourceAccess(['moderator'])).toBe(false);
  });

  it('normalizes role application notes and rejects oversized input', () => {
    expect(normalizeRoleApplicationNote('  Need   technician access  '))
      .toBe('Need technician access');
    expect(normalizeRoleApplicationNote('x'.repeat(1001))).toBeNull();
  });

  it('accepts a complete structured technician application', () => {
    const answers = normalizeRoleApplicationAnswers('technician', {
      primarySpecialty: 'Laptop and desktop diagnostics',
      yearsExperience: 6,
      serviceArea: 'Metro Manila and nearby cities',
      certifications: 'CompTIA A+',
      portfolioUrl: 'https://example.com/profile',
      validIdentificationConfirmed: true,
      backgroundCheckConsent: true,
      phone: '+63 900 000 0000',
      country: 'Philippines',
      city: 'Manila',
      reason: 'I want to provide reliable onsite and remote technical support through HDC.',
      evidenceUrl: '',
      agreedToPlatformStandards: true,
    });

    expect(ROLE_APPLICATION_FORM_VERSION).toBe(2);
    expect(answers?.primarySpecialty).toBe('Laptop and desktop diagnostics');
    expect(answers?.yearsExperience).toBe(6);
  });

  it('rejects missing confirmations and non-HTTPS evidence links', () => {
    expect(normalizeRoleApplicationAnswers('business', {
      businessName: 'HDC Test Business',
      registrationReference: 'REG-123',
      businessType: 'Managed services',
      businessAddress: '123 Example Street',
      contactRole: 'Owner',
      website: 'http://insecure.example.com',
      authorizedRepresentative: false,
      phone: '+63 900 000 0000',
      country: 'Philippines',
      city: 'Manila',
      reason: 'We want to manage verified service requests and staff assignments through HDC.',
      evidenceUrl: '',
      agreedToPlatformStandards: true,
    })).toBeNull();
  });
});
