import crypto from 'node:crypto';

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export function parseEncryptionKey(value = process.env.TOKEN_ENCRYPTION_KEY) {
  if (!value) throw new Error('TOKEN_ENCRYPTION_KEY is required');

  if (/^[0-9a-fA-F]{64}$/.test(value)) {
    return Buffer.from(value, 'hex');
  }

  const decoded = Buffer.from(value, 'base64');
  if (decoded.length === 32) return decoded;

  throw new Error('TOKEN_ENCRYPTION_KEY must decode to exactly 32 bytes');
}

export function encryptToken(plaintext) {
  const key = parseEncryptionKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [iv, tag, ciphertext].map((part) => part.toString('base64url')).join('.');
}

export function decryptToken(payload) {
  const key = parseEncryptionKey();
  const [ivB64, tagB64, ciphertextB64] = String(payload).split('.');
  if (!ivB64 || !tagB64 || !ciphertextB64) throw new Error('Invalid encrypted token payload');

  const decipher = crypto.createDecipheriv('aes-256-gcm', key, Buffer.from(ivB64, 'base64url'));
  decipher.setAuthTag(Buffer.from(tagB64, 'base64url'));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(ciphertextB64, 'base64url')),
    decipher.final()
  ]);
  return plaintext.toString('utf8');
}

export function createOAuthState() {
  const secret = required('STATE_SECRET');
  const payload = Buffer.from(JSON.stringify({
    nonce: crypto.randomBytes(18).toString('base64url'),
    iat: Date.now()
  })).toString('base64url');
  const signature = crypto.createHmac('sha256', secret).update(payload).digest('base64url');
  return `${payload}.${signature}`;
}

export function verifyOAuthState(state, maxAgeMs = 10 * 60 * 1000) {
  try {
    const secret = required('STATE_SECRET');
    const [payload, signature] = String(state || '').split('.');
    if (!payload || !signature) return false;

    const expected = crypto.createHmac('sha256', secret).update(payload).digest('base64url');
    const a = Buffer.from(signature);
    const b = Buffer.from(expected);
    if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return false;

    const parsed = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    return Number.isFinite(parsed.iat) && Date.now() - parsed.iat >= 0 && Date.now() - parsed.iat <= maxAgeMs;
  } catch {
    return false;
  }
}

export function secureEqual(a, b) {
  const left = Buffer.from(String(a ?? ''));
  const right = Buffer.from(String(b ?? ''));
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}
