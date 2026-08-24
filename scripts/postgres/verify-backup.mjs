import {
  createDecipheriv,
  createHash,
} from 'node:crypto';
import {
  closeSync,
  createReadStream,
  createWriteStream,
  existsSync,
  mkdtempSync,
  openSync,
  readFileSync,
  readSync,
  rmSync,
  statSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { pipeline } from 'node:stream/promises';

const MAGIC = Buffer.from('HDCBKP1\n', 'utf8');
const HEADER_BYTES = MAGIC.length + 12;
const AUTH_TAG_BYTES = 16;

function option(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function encryptionKey() {
  const encoded = process.env.HDC_BACKUP_ENCRYPTION_KEY?.trim();
  if (!encoded) throw new Error('HDC_BACKUP_ENCRYPTION_KEY is required.');
  const key = Buffer.from(encoded, 'base64');
  if (key.length !== 32) {
    throw new Error(
      'HDC_BACKUP_ENCRYPTION_KEY must be a base64-encoded 32-byte key.',
    );
  }
  return key;
}

async function sha256(path) {
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest('hex');
}

const backupArgument = option('--backup');
if (!backupArgument) throw new Error('Use --backup with an HDC backup file.');
const backupPath = resolve(backupArgument);
const size = statSync(backupPath).size;
if (size <= HEADER_BYTES + AUTH_TAG_BYTES) {
  throw new Error('The HDC backup file is incomplete.');
}

const descriptor = openSync(backupPath, 'r');
const magic = Buffer.alloc(MAGIC.length);
const iv = Buffer.alloc(12);
const authTag = Buffer.alloc(AUTH_TAG_BYTES);
try {
  readSync(descriptor, magic, 0, magic.length, 0);
  readSync(descriptor, iv, 0, iv.length, MAGIC.length);
  readSync(descriptor, authTag, 0, authTag.length, size - AUTH_TAG_BYTES);
} finally {
  closeSync(descriptor);
}
if (!magic.equals(MAGIC)) throw new Error('Unknown HDC backup format.');

const manifestPath = `${backupPath}.manifest.json`;
if (!existsSync(manifestPath)) {
  throw new Error('The adjacent HDC backup manifest is required.');
}
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
if (
  manifest.format !== 'HDCBKP1' ||
  manifest.encryption !== 'AES-256-GCM' ||
  manifest.source !== 'postgres' ||
  manifest.backupFile !== backupPath.split(/[\\/]/).at(-1) ||
  !/^[a-f0-9]{64}$/.test(String(manifest.checksumSha256 ?? ''))
) {
  throw new Error('The HDC backup manifest is invalid.');
}
const checksum = await sha256(backupPath);
if (manifest.checksumSha256 !== checksum) {
  throw new Error('Backup checksum does not match its manifest.');
}

const temporaryDirectory = mkdtempSync(join(tmpdir(), 'hdc-verify-'));
const plainDumpPath = join(temporaryDirectory, 'verified.dump');
try {
  const decipher = createDecipheriv('aes-256-gcm', encryptionKey(), iv);
  decipher.setAuthTag(authTag);
  await pipeline(
    createReadStream(backupPath, {
      start: HEADER_BYTES,
      end: size - AUTH_TAG_BYTES - 1,
    }),
    decipher,
    createWriteStream(plainDumpPath, { flags: 'wx', mode: 0o600 }),
  );

  const verification = spawnSync(
    'pg_restore',
    ['--list', plainDumpPath],
    { stdio: ['ignore', 'ignore', 'inherit'] },
  );
  if (verification.error) throw verification.error;
  if (verification.status !== 0) {
    throw new Error(`pg_restore verification failed with exit code ${verification.status}.`);
  }
  console.log('HDC backup checksum, encryption, and PostgreSQL archive verified.');
} finally {
  rmSync(temporaryDirectory, { recursive: true, force: true });
}
