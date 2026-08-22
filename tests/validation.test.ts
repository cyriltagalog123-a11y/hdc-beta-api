import { describe, expect, it } from 'vitest';
import {
  normalizeDisplayName,
  normalizeEmail,
  normalizePassword,
} from '../netlify/functions/_lib/validation.mjs';
import {
  RECOVERY_QUESTIONS,
  normalizeRecoveryAnswer,
  parseRecoveryAnswers,
  passwordResetTokenHash,
} from '../netlify/functions/_lib/account-recovery.mjs';

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

  it('normalizes recovery answers without preserving case or spacing', () => {
    expect(normalizeRecoveryAnswer('  Chicken   Adobo  ')).toBe('chicken adobo');
    expect(normalizeRecoveryAnswer('...')).toBeNull();
  });

  it('requires one distinct answer for every fixed recovery question', () => {
    const valid = parseRecoveryAnswers(RECOVERY_QUESTIONS.map((question, index) => ({
      questionCode: question.code,
      answer: `private answer ${index}`,
    })));
    expect(valid).toHaveLength(3);

    expect(parseRecoveryAnswers(RECOVERY_QUESTIONS.map((question) => ({
      questionCode: question.code,
      answer: 'same answer',
    })))).toBeNull();
  });

  it('stores only a deterministic SHA-256 reset token digest', () => {
    expect(passwordResetTokenHash('one-time-token')).toMatch(/^[a-f0-9]{64}$/);
    expect(passwordResetTokenHash('one-time-token')).not.toContain('one-time-token');
  });
});
