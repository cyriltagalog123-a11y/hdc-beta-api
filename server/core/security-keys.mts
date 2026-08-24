import {
  optionalEnvironment,
  requiredEnvironment,
  type EnvironmentReader,
} from './environment.mjs';

const MINIMUM_SECRET_LENGTH = 32;
const KEY_ID_PATTERN = /^[a-z][a-z0-9_-]{2,63}$/;
const LEGACY_RECOVERY_KEY_ID = 'legacy-session-v1';

export type HdcSecretKey = Readonly<{
  keyId: string;
  secret: Uint8Array;
}>;

export type HdcSessionKeyRing = Readonly<{
  current: HdcSecretKey;
  verificationKeys: readonly HdcSecretKey[];
}>;

export type HdcRecoveryPepperKeyRing = Readonly<{
  current: HdcSecretKey;
  verificationKeys: readonly HdcSecretKey[];
}>;

function validatedKeyId(value: string, variableName: string): string {
  if (!KEY_ID_PATTERN.test(value)) {
    throw new Error(`${variableName} must be a lowercase provider-safe key ID.`);
  }
  return value;
}

function secretKey(
  keyId: string,
  secretValue: string,
  variableName: string,
): HdcSecretKey {
  if (secretValue.length < MINIMUM_SECRET_LENGTH) {
    throw new Error(`${variableName} must be at least 32 characters long.`);
  }
  return Object.freeze({
    keyId: validatedKeyId(keyId, `${variableName} key ID`),
    secret: new TextEncoder().encode(secretValue),
  });
}

function uniqueKeys(keys: readonly HdcSecretKey[]): readonly HdcSecretKey[] {
  const seen = new Set<string>();
  const result: HdcSecretKey[] = [];
  for (const key of keys) {
    if (seen.has(key.keyId)) continue;
    seen.add(key.keyId);
    result.push(key);
  }
  return Object.freeze(result);
}

export function loadSessionKeyRing(
  reader: EnvironmentReader,
): HdcSessionKeyRing {
  const currentSecret = requiredEnvironment(reader, 'HDC_SESSION_SECRET');
  const currentKeyId = optionalEnvironment(reader, 'HDC_SESSION_KEY_ID') ??
    'session-v1';
  const current = secretKey(
    currentKeyId,
    currentSecret,
    'HDC_SESSION_SECRET',
  );

  const previousSecret = optionalEnvironment(
    reader,
    'HDC_SESSION_SECRET_PREVIOUS',
  );
  if (!previousSecret) {
    return Object.freeze({
      current,
      verificationKeys: Object.freeze([current]),
    });
  }

  const previousKeyId = optionalEnvironment(
    reader,
    'HDC_SESSION_SECRET_PREVIOUS_KEY_ID',
  ) ?? 'session-previous';
  const previous = secretKey(
    previousKeyId,
    previousSecret,
    'HDC_SESSION_SECRET_PREVIOUS',
  );
  if (previous.keyId === current.keyId) {
    throw new Error('Current and previous HDC session key IDs must differ.');
  }

  return Object.freeze({
    current,
    verificationKeys: uniqueKeys([current, previous]),
  });
}

export function loadRecoveryPepperKeyRing(
  reader: EnvironmentReader,
): HdcRecoveryPepperKeyRing {
  const sessionKeys = loadSessionKeyRing(reader);
  const configuredCurrent = optionalEnvironment(reader, 'HDC_RECOVERY_PEPPER');

  const current = configuredCurrent
    ? secretKey(
        optionalEnvironment(reader, 'HDC_RECOVERY_PEPPER_KEY_ID') ??
          'recovery-v1',
        configuredCurrent,
        'HDC_RECOVERY_PEPPER',
      )
    : Object.freeze({
        keyId: LEGACY_RECOVERY_KEY_ID,
        secret: sessionKeys.current.secret,
      });

  const configuredLegacy = optionalEnvironment(
    reader,
    'HDC_RECOVERY_LEGACY_PEPPER',
  );
  const legacy = configuredLegacy
    ? secretKey(
        LEGACY_RECOVERY_KEY_ID,
        configuredLegacy,
        'HDC_RECOVERY_LEGACY_PEPPER',
      )
    : Object.freeze({
        keyId: LEGACY_RECOVERY_KEY_ID,
        secret: sessionKeys.current.secret,
      });

  return Object.freeze({
    current,
    verificationKeys: uniqueKeys([current, legacy]),
  });
}

export function recoveryPepperForKey(
  reader: EnvironmentReader,
  keyId: string,
): HdcSecretKey | null {
  return loadRecoveryPepperKeyRing(reader).verificationKeys.find(
    (key) => key.keyId === keyId,
  ) ?? null;
}

export function loadIdentityFingerprintSecret(
  reader: EnvironmentReader,
): Uint8Array {
  const configured = optionalEnvironment(
    reader,
    'HDC_IDENTITY_FINGERPRINT_SECRET',
  );
  if (!configured) return loadSessionKeyRing(reader).current.secret;
  return secretKey(
    'identity-fingerprint-v1',
    configured,
    'HDC_IDENTITY_FINGERPRINT_SECRET',
  ).secret;
}
