export const BACKUP_MANIFEST_VERSION: 5;

export function authenticateManifest<T extends Record<string, unknown>>(
  unsignedManifest: T,
  key: Buffer,
): T & { manifestHmacSha256: string };

export function verifyManifestAuthentication(
  manifest: Record<string, unknown>,
  key: Buffer,
): Record<string, unknown>;
