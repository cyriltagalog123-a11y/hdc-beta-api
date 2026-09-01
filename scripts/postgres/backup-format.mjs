import {
  createHmac,
  timingSafeEqual,
} from 'node:crypto';

export const BACKUP_MANIFEST_VERSION = 5;

function hmacFor(manifest, key) {
  return createHmac('sha256', key)
    .update(JSON.stringify(manifest))
    .digest('hex');
}

export function authenticateManifest(unsignedManifest, key) {
  if (!Buffer.isBuffer(key) || key.length !== 32) {
    throw new Error('A 32-byte manifest authentication key is required.');
  }
  if (
    !unsignedManifest ||
    typeof unsignedManifest !== 'object' ||
    Array.isArray(unsignedManifest) ||
    'manifestHmacSha256' in unsignedManifest
  ) {
    throw new Error('The unsigned backup manifest is invalid.');
  }
  return {
    ...unsignedManifest,
    manifestHmacSha256: hmacFor(unsignedManifest, key),
  };
}

export function verifyManifestAuthentication(manifest, key) {
  if (!Buffer.isBuffer(key) || key.length !== 32) {
    throw new Error('A 32-byte manifest authentication key is required.');
  }
  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) {
    throw new Error('The HDC backup manifest is invalid.');
  }
  const { manifestHmacSha256, ...unsignedManifest } = manifest;
  if (!/^[a-f0-9]{64}$/.test(String(manifestHmacSha256 ?? ''))) {
    throw new Error('The HDC backup manifest authentication is missing.');
  }
  const expected = Buffer.from(hmacFor(unsignedManifest, key), 'hex');
  const actual = Buffer.from(manifestHmacSha256, 'hex');
  if (
    actual.length !== expected.length ||
    !timingSafeEqual(actual, expected)
  ) {
    throw new Error('The HDC backup manifest authentication failed.');
  }
  return unsignedManifest;
}
