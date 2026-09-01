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
  authenticateManifest,
  BACKUP_MANIFEST_VERSION,
} from './backup-format.mjs';
import {
  PORTABLE_BACKUP_EXCLUDED_EXTENSIONS,
  PORTABLE_BACKUP_EXCLUDED_SCHEMAS,
  parseBackupDatabaseUrl,
  pgDumpArguments,
} from './backup-command.mjs';
import { capturePortablePrivileges } from './portable-privileges.mjs';

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

async function backupMetadata(databaseUrl) {
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
    const inventory = {
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

    const audits = await sql.unsafe(`
      WITH definitions AS (
        SELECT
          'policy'::text AS object_kind,
          tablename || '.' || policyname AS object_name,
          concat_ws(' ', qual, with_check) AS definition
        FROM pg_policies
        WHERE schemaname = 'public' AND tablename LIKE 'hdc_%'

        UNION ALL

        SELECT
          'function',
          procedure.proname || '(' ||
            pg_get_function_identity_arguments(procedure.oid) || ')',
          pg_get_functiondef(procedure.oid)
        FROM pg_proc procedure
        JOIN pg_namespace namespace
          ON namespace.oid = procedure.pronamespace
        WHERE namespace.nspname = 'public'
          AND procedure.proname LIKE 'hdc_%'
          AND procedure.prokind IN ('f', 'p')

        UNION ALL

        SELECT 'view', viewname, definition
        FROM pg_views
        WHERE schemaname = 'public' AND viewname LIKE 'hdc_%'

        UNION ALL

        SELECT
          'default',
          relation.relname || '.' || attribute.attname,
          pg_get_expr(default_value.adbin, default_value.adrelid)
        FROM pg_attrdef default_value
        JOIN pg_attribute attribute
          ON attribute.attrelid = default_value.adrelid
          AND attribute.attnum = default_value.adnum
        JOIN pg_class relation ON relation.oid = default_value.adrelid
        JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
        WHERE namespace.nspname = 'public'
          AND relation.relname LIKE 'hdc_%'

        UNION ALL

        SELECT
          'constraint',
          constraint_object.conname,
          pg_get_constraintdef(constraint_object.oid, true)
        FROM pg_constraint constraint_object
        JOIN pg_namespace namespace
          ON namespace.oid = constraint_object.connamespace
        JOIN pg_class relation
          ON relation.oid = constraint_object.conrelid
        WHERE namespace.nspname = 'public'
          AND left(relation.relname, 4) = 'hdc_'
      ),
      provider_references AS (
        SELECT object_kind, object_name
        FROM definitions
        WHERE lower(definition) ~
          '(^|[^a-z0-9_])(auth|neon_auth|pgrst|pg_session_jwt|cloud_admin|neon_superuser|authenticator|authenticated|anonymous|neon_service)([^a-z0-9_]|$)'
      ),
      nonportable_policy_roles AS (
        SELECT tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename LIKE 'hdc_%'
          AND EXISTS (
            SELECT 1
            FROM unnest(roles) policy_role
            WHERE policy_role NOT IN ('public', 'hdc_app')
          )
      )
      SELECT jsonb_build_object(
        'version', 1,
        'unknownSchemas', COALESCE((
          SELECT jsonb_agg(namespace.nspname ORDER BY namespace.nspname)
          FROM pg_namespace namespace
          WHERE namespace.nspname NOT LIKE 'pg_%'
            AND namespace.nspname <> 'information_schema'
            AND namespace.nspname NOT IN (
              'public', 'auth', 'neon_auth', 'pgrst'
            )
        ), '[]'::jsonb),
        'unknownExtensions', COALESCE((
          SELECT jsonb_agg(extension.extname ORDER BY extension.extname)
          FROM pg_extension extension
          WHERE extension.extname NOT IN (
            'plpgsql', 'pgcrypto', 'citext', 'pg_session_jwt'
          )
        ), '[]'::jsonb),
        'providerReferences', COALESCE((
          SELECT jsonb_agg(to_jsonb(reference) ORDER BY
            reference.object_kind, reference.object_name)
          FROM provider_references reference
        ), '[]'::jsonb),
        'nonportablePolicyRoles', COALESCE((
          SELECT jsonb_agg(to_jsonb(policy) ORDER BY
            policy.tablename, policy.policyname)
          FROM nonportable_policy_roles policy
        ), '[]'::jsonb),
        'unvalidatedConstraints', (
          SELECT count(*)::int
          FROM pg_constraint constraint_object
          JOIN pg_namespace namespace
            ON namespace.oid = constraint_object.connamespace
          WHERE namespace.nspname = 'public'
            AND NOT constraint_object.convalidated
        ),
        'invalidIndexes', (
          SELECT count(*)::int
          FROM pg_index index_object
          JOIN pg_class relation ON relation.oid = index_object.indexrelid
          JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
          WHERE namespace.nspname = 'public' AND NOT index_object.indisvalid
        ),
        'disabledUserTriggers', (
          SELECT count(*)::int
          FROM pg_trigger trigger_object
          JOIN pg_class relation ON relation.oid = trigger_object.tgrelid
          JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
          WHERE namespace.nspname = 'public'
            AND NOT trigger_object.tgisinternal
            AND trigger_object.tgenabled = 'D'
        ),
        'eventTriggers', (SELECT count(*)::int FROM pg_event_trigger),
        'hdcForeignTables', (
          SELECT count(*)::int
          FROM pg_class relation
          JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
          WHERE namespace.nspname = 'public'
            AND relation.relname LIKE 'hdc_%'
            AND relation.relkind = 'f'
        ),
        'hdcPublicationTables', (
          SELECT count(*)::int
          FROM pg_publication_rel publication_relation
          JOIN pg_class relation ON relation.oid = publication_relation.prrelid
          JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
          WHERE namespace.nspname = 'public'
            AND relation.relname LIKE 'hdc_%'
        )
      ) AS audit
    `);
    const portabilityAudit = audits[0]?.audit;
    const auditArrays = [
      portabilityAudit?.unknownSchemas,
      portabilityAudit?.unknownExtensions,
      portabilityAudit?.providerReferences,
      portabilityAudit?.nonportablePolicyRoles,
    ];
    const auditCounts = [
      portabilityAudit?.unvalidatedConstraints,
      portabilityAudit?.invalidIndexes,
      portabilityAudit?.disabledUserTriggers,
      portabilityAudit?.eventTriggers,
      portabilityAudit?.hdcForeignTables,
      portabilityAudit?.hdcPublicationTables,
    ];
    if (
      portabilityAudit?.version !== 1 ||
      auditArrays.some((value) => !Array.isArray(value) || value.length > 0) ||
      auditCounts.some((value) => Number(value) !== 0)
    ) {
      throw new Error(
        `HDC portability preflight failed: ${JSON.stringify(portabilityAudit)}`,
      );
    }

    const portablePrivileges = await capturePortablePrivileges(sql);
    return { inventory, portabilityAudit, portablePrivileges };
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
  const key = encryptionKey();
  const metadata = await backupMetadata(databaseUrl);
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
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const output = createWriteStream(backupPath, { flags: 'wx', mode: 0o600 });
  output.write(MAGIC);
  output.write(iv);
  await pipeline(createReadStream(plainDumpPath), cipher, output, { end: false });
  const finished = once(output, 'finish');
  output.end(cipher.getAuthTag());
  await finished;

  const checksumSha256 = await sha256(backupPath);
  const manifest = authenticateManifest({
    format: 'HDCBKP1',
    manifestVersion: BACKUP_MANIFEST_VERSION,
    encryption: 'AES-256-GCM',
    source: 'postgres',
    sourceDatabase,
    privilegeMode: 'authenticated-hdc-allowlist-v1',
    excludedExtensions: [...PORTABLE_BACKUP_EXCLUDED_EXTENSIONS],
    excludedSchemas: [...PORTABLE_BACKUP_EXCLUDED_SCHEMAS],
    createdAt: new Date().toISOString(),
    backupFile: basename(backupPath),
    checksumSha256,
    inventory: metadata.inventory,
    portabilityAudit: metadata.portabilityAudit,
    portablePrivileges: metadata.portablePrivileges,
  }, key);
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
