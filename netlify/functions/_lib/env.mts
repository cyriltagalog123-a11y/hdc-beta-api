export function requireEnv(name: string): string {
  const value = Netlify.env.get(name)?.trim();
  if (!value) {
    throw new Error(`Missing required server environment variable: ${name}`);
  }
  return value;
}

export function databaseUrl(): string {
  return requireEnv('DATABASE_URL');
}

export function sessionSecret(): Uint8Array {
  const secret = requireEnv('HDC_SESSION_SECRET');
  if (secret.length < 32) {
    throw new Error('HDC_SESSION_SECRET must be at least 32 characters long.');
  }
  return new TextEncoder().encode(secret);
}

export function securityReviewEmail(): string | null {
  const value = Netlify.env.get('HDC_SECURITY_REVIEW_EMAIL')?.trim().toLowerCase();
  return value || null;
}
