import { describe, expect, it } from 'vitest';
import { technicianDirectoryEntryView } from '../netlify/functions/_lib/public-technicians.mjs';
import { normalizePlatformRoleProfileWrite, TECHNICIAN_PUBLIC_FIELDS } from '../netlify/functions/_lib/profiles.mjs';

const row = {
  id: 'public-profile', public_member_id: 'HDC-MEMBER', public_name: 'Jamie Repairs',
  user_id: 'private-account-id', email: 'login@example.invalid',
  avatar_url: 'https://example.invalid/photo.png', headline: 'Diagnostics',
  description: 'Private description', location: 'Private service area',
  contact_email: 'contact@example.invalid', contact_phone: '+639121234567',
  website: 'https://example.invalid/', is_public: true,
  rating_count: 2, average_rating: '4.50', completed_services: 3,
  details: {
    skills: ['Soldering'], specialties: ['Laptops'], yearsExperience: 7,
    serviceRadiusKm: 25, hourlyRate: 500, availability: 'Weekdays', emergencyService: true,
  },
  updated_at: new Date('2026-09-15T00:00:00Z'),
};

describe('Build 27 public technician projection', () => {
  it('exposes core identity and earned reputation while withholding all optional fields by default', () => {
    const result = technicianDirectoryEntryView(row);
    expect(result).toMatchObject({ publicName: 'Jamie Repairs', avatarUrl: row.avatar_url,
      details: { yearsExperience: 7 }, ratingCount: 2, averageRating: 4.5, completedServices: 3,
      contactEmail: '', contactPhone: '', website: '', headline: '', description: '', location: '' });
    expect(result.details).toEqual({ yearsExperience: 7 });
    const serialized = JSON.stringify(result);
    for (const privateValue of [row.user_id, row.email, row.contact_email, row.contact_phone, row.description, row.location, 'Soldering']) {
      expect(serialized).not.toContain(privateValue);
    }
  });

  it('publishes only the exact selected fields and never returns the preference document', () => {
    const result = technicianDirectoryEntryView({ ...row, details: {
      ...row.details, publicFields: ['skills', 'contactEmail', 'hourlyRate'],
    } });
    expect(result.contactEmail).toBe(row.contact_email);
    expect(result.contactPhone).toBe('');
    expect(result.details).toEqual({ yearsExperience: 7, skills: ['Soldering'], hourlyRate: 500 });
    expect(result).not.toHaveProperty('userId');
    expect(result.details).not.toHaveProperty('publicFields');
  });

  it('fails closed on malformed preferences and ignores client-supplied reputation', () => {
    const result = technicianDirectoryEntryView({ ...row, rating_count: 0, average_rating: null,
      details: { ...row.details, publicFields: { contactEmail: true }, ratingCount: 999, averageRating: 5 },
    });
    expect(result.contactEmail).toBe('');
    expect(result.ratingCount).toBe(0);
    expect(result.averageRating).toBeNull();
    expect(result.details).toEqual({ yearsExperience: 7 });
  });

  it.each(['javascript:alert(1)', 'http://example.invalid/photo.png', 'data:image/svg+xml,unsafe'])(
    'does not expose an unsafe or mixed-content photo URL: %s', (avatar_url) => {
      expect(technicianDirectoryEntryView({ ...row, avatar_url }).avatarUrl).toBe('');
    },
  );

  it('keeps approved technicians discoverable and defaults optional sharing to empty', () => {
    const result = normalizePlatformRoleProfileWrite('technician', { publicName: 'Jamie', isPublic: false });
    expect(result?.isPublic).toBe(true);
    expect(result?.details.publicFields).toEqual([]);
    expect(normalizePlatformRoleProfileWrite('customer', { publicName: 'Jamie', isPublic: false })?.isPublic).toBe(false);
  });

  it('accepts the full optional field set and rejects unknown or core reputation controls', () => {
    expect(normalizePlatformRoleProfileWrite('technician', {
      publicName: 'Jamie', details: { publicFields: [...TECHNICIAN_PUBLIC_FIELDS] },
    })?.details.publicFields).toEqual(TECHNICIAN_PUBLIC_FIELDS);
    for (const key of ['ratingCount', 'reviews', 'yearsExperience', 'publicName', 'email', 'userId']) {
      expect(normalizePlatformRoleProfileWrite('technician', {
        publicName: 'Jamie', details: { publicFields: [key] },
      }), key).toBeNull();
    }
  });
});
