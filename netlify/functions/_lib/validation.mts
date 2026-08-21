const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function normalizeEmail(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const email = value.trim().toLowerCase();
  if (email.length < 3 || email.length > 254 || !EMAIL_RE.test(email)) return null;
  return email;
}

export function normalizeDisplayName(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const name = value.trim().replace(/\s+/g, ' ');
  if (name.length < 2 || name.length > 80) return null;
  return name;
}

export function normalizePassword(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  if (value.length < 12 || value.length > 128) return null;
  return value;
}
