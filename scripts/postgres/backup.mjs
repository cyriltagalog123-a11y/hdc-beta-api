import {
  createCipheriv,
  createHash,
  randomBytes,
} from 'node:crypto';
import {
  createReadStream,
  createWriteStream,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { basename, join, parse, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { once } from 'node:events';
import { pipeline } from 'node:stream/promises';
import postgres from 'postgres';

import {
  PORTABLE_BACKUP_EXCLUDED_EXTENSIONS,
  PORTABLE_BACKUP_EXCLUDED_SCHEMAS,
  parseBackupDatabaseUrl,
  pgDumpArguments,
} from './backup-command.mjs';

const MAGIC = Buffer.from('HDCBKP1\n', 'utf8');

function option(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function requiredSecret(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function encryptionKey() {
  const encoded = requiredSecret('HDC_BACKUP_ENCRYPTION_KEY');
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

async function backupInventory(databaseUrl) {
  const sql = postgres(databaseUrl, {
    max: 1,
    prepare: false,
    connect_timeout: 10,
    idle_timeout: 10,
  });
  try {
    const rows = await sql`
      SELECT
        (SELECT count(*)::int FROM public.hdc_users) AS users,
        (SELECT count(*)::int FROM public.hdc_service_requests)
          AS service_requests,
        (SELECT count(*)::int FROM public.hdc_proposals) AS proposals,
        (SELECT count(*)::int FROM public.hdc_service_transactions)
          AS service_transactions,
        (SELECT count(*)::int FROM public.hdc_private_messages)
          AS private_messages,
        (SELECT count(*)::int FROM public.hdc_service_payments) AS payments,
        (SELECT count(*)::int FROM public.hdc_service_payment_events)
          AS payment_events,
        (SELECT count(*)::int FROM public.hdc_service_receipts) AS receipts,
        (SELECT count(*)::int FROM public.hdc_service_documents) AS documents,
        (SELECT count(*)::int FROM public.hdc_service_disputes) AS disputes,
        (SELECT count(*)::int FROM public.hdc_service_dispute_events)
          AS dispute_events,
        (SELECT count(*)::int FROM public.hdc_security_audit) AS security_audit,
        (SELECT array_agg(version ORDER BY version)
          FROM public.hdc_schema_migrations) AS migration_versions
    `;
    const row = rows[0];
    return {
      users: Number(row.users),
      serviceRequests: Number(row.service_requests),
      proposals: Number(row.proposals),
      serviceTransactions: Number(row.service_transactions),
      privateMessages: Number(row.private_messages),
      payments: Number(row.payments),
      paymentEvents: Number(row.payment_events),
      receipts: Number(row.receipts),
      documents: Number(row.documents),
      disputes: Number(row.disputes),
      disputeEvents: Number(row.dispute_events),
      securityAudit: Number(row.security_audit),
      migrationVersions: [...(row.migration_versions ?? [])].map(String),
    };
  } finally {
    await sql.end({ timeout: 2 });
  }
}

const outputArgument = option('--output');
if (!outputArgument) {
  throw new Error('Use --output with a dedicated backup directory.');
}
const outputDirectory = resolve(outputArgument);
if (outputDirectory === parse(outputDirectory).root || outputDirectory === homedir()) {
  throw new Error('Refusing to use a broad system or home directory for backups.');
}

const databaseUrl = process.env.HDC_DATABASE_URL?.trim() ||
  process.env.DATABASE_URL?.trim();
if (!databaseUrl) {
  throw new Error('HDC_DATABASE_URL (or legacy DATABASE_URL) is required.');
}
const databaseConnection = parseBackupDatabaseUrl(databaseUrl);
const sourceDatabase = decodeURIComponent(
  databaseConnection.pathname.replace(/^\//, ''),
);

mkdirSync(outputDirectory, { recursive: true });
const temporaryDirectory = mkdtempSync(join(tmpdir(), 'hdc-backup-'));
const plainDumpPath = join(temporaryDirectory, 'hdc-postgres.dump');
const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
const backupPath = join(outputDirectory, `hdc-${timestamp}.hdcbackup`);
const manifestPath = `${backupPath}.manifest.json`;
let backupComplete = false;

try {
  const inventory = await backupInventory(databaseUrl);
  const dump = spawnSync(
    'pg_dump',
    pgDumpArguments(databaseUrl, plainDumpPath),
    {
      env: { ...process.env },
      stdio: ['ignore', 'inherit', 'inherit'],
    },
  );
  if (dump.error) throw dump.error;
  if (dump.status !== 0) {
    throw new Error(`pg_dump failed with exit code ${dump.status}.`);
  }

  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', encryptionKey(), iv);
  const output = createWriteStream(backupPath, { flags: 'wx', mode: 0o600 });
  output.write(MAGIC);
  output.write(iv);
  await pipeline(createReadStream(plainDumpPath), cipher, output, { end: false });
  const finished = once(output, 'finish');
  output.end(cipher.getAuthTag());
  await finished;

  const checksumSha256 = await sha256(backupPath);
  const manifest = {
    format: 'HDCBKP1',
    manifestVersion: 4,
    encryption: 'AES-256-GCM',
    source: 'postgres',
    sourceDatabase,
    excludedExtensions: [...PORTABLE_BACKUP_EXCLUDED_EXTENSIONS],
    excludedSchemas: [...PORTABLE_BACKUP_EXCLUDED_SCHEMAS],
    createdAt: new Date().toISOString(),
    backupFile: basename(backupPath),
    checksumSha256,
    inventory,
  };
  writeFileSync(
    manifestPath,
    `${JSON.stringify(manifest, null, 2)}\n`,
    { flag: 'wx', mode: 0o600 },
  );
  backupComplete = true;
  console.log(`Encrypted HDC backup: ${backupPath}`);
  console.log(`Manifest: ${manifestPath}`);
  console.log(`SHA-256: ${checksumSha256}`);
} finally {
  rmSync(temporaryDirectory, { recursive: true, force: true });
  if (!backupComplete) {
    rmSync(backupPath, { force: true });
    rmSync(manifestPath, { force: true });
  }
}
