import { describe, expect, it } from 'vitest';
import {
  normalizeMemberProfileWrite,
  normalizePlatformRoleProfileWrite,
} from '../netlify/functions/_lib/profiles.mjs';

describe('HDC one-account role profiles', () => {
  it('normalizes the single shared member profile', () => {
    expect(normalizeMemberProfileWrite({
      displayName: '  Jamie   Cruz ',
      bio: ' HDC member ',
      location: ' Manila ',
      avatarUrl: 'https://example.com/avatar.png',
      contactPreference: 'in_app',
    })).toEqual({
      displayName: 'Jamie Cruz',
      bio: 'HDC member',
      location: 'Manila',
      avatarUrl: 'https://example.com/avatar.png',
      contactPreference: 'in_app',
    });
  });

  it('keeps technician details typed and role-specific', () => {
    const result = normalizePlatformRoleProfileWrite('technician', {
      publicName: 'Jamie Repairs',
      headline: 'Device technician',
      description: 'Mobile and computer repair',
      location: 'Manila',
      contactEmail: 'JAMIE@example.com',
      contactPhone: '+63 912 345 6789',
      website: 'https://example.com',
      isPublic: true,
      details: {
        skills: ['Diagnostics', 'Diagnostics', 'Soldering'],
        specialties: ['Mobile devices'],
        yearsExperience: 8,
        serviceRadiusKm: 25,
        hourlyRate: 850,
        availability: 'Weekdays',
        emergencyService: false,
      },
    });

    expect(result?.contactEmail).toBe('jamie@example.com');
    expect(result?.details.skills).toEqual(['Diagnostics', 'Soldering']);
    expect(result?.details.yearsExperience).toBe(8);
  });

  it('accepts a distinct detail schema for all six platform roles', () => {
    const cases: Array<{
      role: Parameters<typeof normalizePlatformRoleProfileWrite>[0];
      details: Record<string, unknown>;
    }> = [
      {
        role: 'customer',
        details: {
          preferredServiceMode: 'either',
          supportInterests: ['Computers'],
        },
      },
      {
        role: 'technician',
        details: { skills: ['Diagnostics'], emergencyService: true },
      },
      {
        role: 'business',
        details: { legalName: 'HDC Business Inc.', branchCount: 2 },
      },
      {
        role: 'seller',
        details: { storefrontName: 'HDC Seller', productCategories: ['Parts'] },
      },
      {
        role: 'supplier',
        details: { companyName: 'HDC Supply', deliveryRegions: ['Luzon'] },
      },
      {
        role: 'store',
        details: { storeName: 'HDC Store One', pickupAvailable: true },
      },
    ];

    for (const value of cases) {
      expect(normalizePlatformRoleProfileWrite(value.role, {
        publicName: `${value.role} profile`,
        isPublic: false,
        details: value.details,
      }), value.role).not.toBeNull();
    }
  });

  it('rejects details belonging to another role', () => {
    expect(normalizePlatformRoleProfileWrite('customer', {
      publicName: 'Jamie Cruz',
      isPublic: false,
      details: { skills: ['Repair'] },
    })).toBeNull();
  });

  it('rejects invalid public contact and numeric limits', () => {
    expect(normalizePlatformRoleProfileWrite('supplier', {
      publicName: 'HDC Parts Supply',
      contactEmail: 'not-an-email',
      isPublic: true,
      details: {},
    })).toBeNull();

    expect(normalizePlatformRoleProfileWrite('technician', {
      publicName: 'Jamie Repairs',
      isPublic: true,
      details: { yearsExperience: 500 },
    })).toBeNull();
  });
});
