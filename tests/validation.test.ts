import { describe, expect, it } from 'vitest';
import {
  normalizeDisplayName,
  normalizeEmail,
  normalizePassword,
} from '../netlify/functions/_lib/validation.mjs';

describe('authentication validation', () => {
  it('normalizes a valid email', () => {
    expect(normalizeEmail('  User@Example.COM ')).toBe('user@example.com');
  });

  it('rejects malformed email values', () => {
    expect(normalizeEmail('not-an-email')).toBeNull();
    expect(normalizeEmail('')).toBeNull();
  });

  it('normalizes display names without accepting tiny names', () => {
    expect(normalizeDisplayName('  HDC   Beta Customer ')).toBe('HDC Beta Customer');
    expect(normalizeDisplayName('A')).toBeNull();
  });

  it('enforces the beta password length policy', () => {
    expect(normalizePassword('short')).toBeNull();
    expect(normalizePassword('HDC-Secure#123')).toBe('HDC-Secure#123');
  });
});
