import {
  firstEnvironment,
  optionalEnvironment,
  processEnvironmentReader,
  requiredEnvironment,
} from '../../../server/core/environment.mjs';
import {
  loadIdentityFingerprintSecret,
  loadRecoveryPepperKeyRing,
  loadSessionKeyRing,
  recoveryPepperForKey as findRecoveryPepperForKey,
  type HdcSecretKey,
} from '../../../server/core/security-keys.mjs';
import {
  loadOperationMode,
  type HdcOperationMode,
} from '../../../server/core/operation-mode.mjs';

const runtimeEnvironment = processEnvironmentReader;

export function requireEnv(name: string): string {
  return requiredEnvironment(runtimeEnvironment, name);
}

export function databaseDriver(): 'postgres' {
  const driver = optionalEnvironment(
    runtimeEnvironment,
    'HDC_DATABASE_DRIVER',
  )?.toLowerCase() ?? 'postgres';
  if (driver !== 'postgres') {
    throw new Error(`Unsupported HDC database driver: ${driver}`);
  }
  return driver;
}

export function databaseUrl(): string {
  const value = firstEnvironment(runtimeEnvironment, [
    'HDC_DATABASE_URL',
    'DATABASE_URL',
  ]);
  if (!value) {
    throw new Error(
      'Missing required server environment variable: HDC_DATABASE_URL',
    );
  }
  return value;
}

export function sessionSecret(): Uint8Array {
  return loadSessionKeyRing(runtimeEnvironment).current.secret;
}

export function sessionKeyId(): string {
  return loadSessionKeyRing(runtimeEnvironment).current.keyId;
}

export function sessionVerificationKeys(): readonly HdcSecretKey[] {
  return loadSessionKeyRing(runtimeEnvironment).verificationKeys;
}

export function currentRecoveryPepper(): HdcSecretKey {
  return loadRecoveryPepperKeyRing(runtimeEnvironment).current;
}

export function recoveryPepperForKey(keyId: string): HdcSecretKey | null {
  return findRecoveryPepperForKey(runtimeEnvironment, keyId);
}

export function identityFingerprintSecret(): Uint8Array {
  return loadIdentityFingerprintSecret(runtimeEnvironment);
}

export function operationMode(): HdcOperationMode {
  return loadOperationMode(runtimeEnvironment);
}

export function securityReviewEmail(): string | null {
  return optionalEnvironment(
    runtimeEnvironment,
    'HDC_SECURITY_REVIEW_EMAIL',
  )?.toLowerCase() ?? null;
}

export function webAllowedOrigins(): readonly string[] {
  const value = optionalEnvironment(
    runtimeEnvironment,
    'HDC_WEB_ALLOWED_ORIGINS',
  );
  if (!value) return [];
  return Object.freeze(
    value.split(',').map((item) => item.trim()).filter(Boolean),
  );
}
