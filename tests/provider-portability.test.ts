import { describe, expect, it } from 'vitest';
import { handleHdcApiRequest } from '../netlify/functions/api.mjs';
import {
  firstEnvironment,
  optionalEnvironment,
  requiredEnvironment,
  type EnvironmentReader,
} from '../server/core/environment.mjs';
import {
  loadProviderSelection,
  loadProviderSelections,
} from '../server/core/provider-config.mjs';
import {
  HdcProviderRegistry,
  HdcProviderUnavailableError,
} from '../server/core/provider-registry.mjs';
import {
  loadOperationMode,
  operationDecision,
} from '../server/core/operation-mode.mjs';
import {
  loadRecoveryPepperKeyRing,
  loadSessionKeyRing,
  recoveryPepperForKey,
} from '../server/core/security-keys.mjs';

function environment(values: Record<string, string>): EnvironmentReader {
  return (name) => values[name];
}

function decoded(value: Uint8Array): string {
  return new TextDecoder().decode(value);
}

describe('provider-neutral environment', () => {
  it('exposes a hosting-neutral Web API handler', async () => {
    const response = await handleHdcApiRequest(
      new Request('https://api.hdc.invalid/api/health'),
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      service: 'hdc-beta-api',
      status: 'ok',
      build: '0.6.4-build15',
    });
  });

  it('trims values and supports branded-to-legacy fallback order', () => {
    const reader = environment({
      HDC_DATABASE_URL: '  postgres://primary  ',
      DATABASE_URL: 'postgres://legacy',
    });
    expect(optionalEnvironment(reader, 'HDC_DATABASE_URL')).toBe(
      'postgres://primary',
    );
    expect(firstEnvironment(reader, ['HDC_DATABASE_URL', 'DATABASE_URL'])).toBe(
      'postgres://primary',
    );
  });

  it('fails closed when a required value is absent', () => {
    expect(() => requiredEnvironment(environment({}), 'HDC_SESSION_SECRET'))
      .toThrow(/HDC_SESSION_SECRET/);
  });

  it('can freeze writes without depending on a hosting control panel', () => {
    const mode = loadOperationMode(
      environment({ HDC_OPERATION_MODE: 'read_only' }),
    );
    expect(operationDecision(mode, 'GET', '/api/profiles').allowed).toBe(true);
    expect(operationDecision(mode, 'POST', '/api/proposals')).toMatchObject({
      allowed: false,
      errorCode: 'service_read_only',
    });
    expect(operationDecision('incident', 'GET', '/api/health').allowed).toBe(
      true,
    );
  });
});

describe('rotatable security keys', () => {
  it('signs with the current key and retains one previous verification key', () => {
    const reader = environment({
      HDC_SESSION_KEY_ID: 'session-v2',
      HDC_SESSION_SECRET: 'current-session-secret-1234567890',
      HDC_SESSION_SECRET_PREVIOUS_KEY_ID: 'session-v1',
      HDC_SESSION_SECRET_PREVIOUS: 'previous-session-secret-12345678',
    });
    const ring = loadSessionKeyRing(reader);
    expect(ring.current.keyId).toBe('session-v2');
    expect(ring.verificationKeys.map((key) => key.keyId)).toEqual([
      'session-v2',
      'session-v1',
    ]);
  });

  it('preserves Build 12 recovery hashes when a new pepper is introduced', () => {
    const reader = environment({
      HDC_SESSION_SECRET: 'new-session-secret-12345678901234',
      HDC_RECOVERY_PEPPER_KEY_ID: 'recovery-v2',
      HDC_RECOVERY_PEPPER: 'current-recovery-pepper-123456789',
      HDC_RECOVERY_LEGACY_PEPPER: 'legacy-session-secret-123456789012',
    });
    const ring = loadRecoveryPepperKeyRing(reader);
    expect(ring.current.keyId).toBe('recovery-v2');
    expect(
      decoded(recoveryPepperForKey(reader, 'legacy-session-v1')!.secret),
    ).toBe('legacy-session-secret-123456789012');
  });

  it('uses the session secret only as a migration-compatible fallback', () => {
    const reader = environment({
      HDC_SESSION_SECRET: 'session-secret-for-build12-123456789',
    });
    const ring = loadRecoveryPepperKeyRing(reader);
    expect(ring.current.keyId).toBe('legacy-session-v1');
    expect(decoded(ring.current.secret)).toBe(
      'session-secret-for-build12-123456789',
    );
  });
});

describe('external provider selection', () => {
  it('keeps every paid provider disabled by default', () => {
    const selections = loadProviderSelections(environment({}));
    expect(selections.every((selection) => !selection.configured)).toBe(true);
    expect(selections.find((item) => item.capability === 'email')?.failureMode)
      .toBe('queue');
    expect(selections.find((item) => item.capability === 'payment')?.failureMode)
      .toBe('fail_closed');
  });

  it('accepts a provider adapter key without exposing credentials', () => {
    const selection = loadProviderSelection(
      environment({ HDC_OBJECT_STORAGE_PROVIDER: 's3_compatible' }),
      'object_storage',
    );
    expect(selection.providerKey).toBe('s3_compatible');
    expect(selection.configured).toBe(true);
  });

  it('rejects malformed provider keys', () => {
    expect(() => loadProviderSelection(
      environment({ HDC_EMAIL_PROVIDER: 'https://vendor.example' }),
      'email',
    )).toThrow(/invalid provider key/);
  });

  it('resolves only explicitly registered adapters', () => {
    const selection = loadProviderSelection(
      environment({ HDC_EMAIL_PROVIDER: 'test_mail' }),
      'email',
    );
    const registry = new HdcProviderRegistry([
      { providerKey: 'test_mail', description: 'contract-test adapter' },
    ]);
    expect(registry.required(selection).description).toBe(
      'contract-test adapter',
    );
    expect(() => new HdcProviderRegistry([]).required(selection)).toThrow(
      HdcProviderUnavailableError,
    );
  });
});
