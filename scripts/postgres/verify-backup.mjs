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
import postgres from 'postgres';

import {
  BACKUP_MANIFEST_VERSION,
  verifyManifestAuthentication,
} from './backup-format.mjs';
import {
  PORTABLE_BACKUP_EXCLUDED_EXTENSIONS,
  PORTABLE_BACKUP_EXCLUDED_SCHEMAS,
} from './backup-command.mjs';
import {
  applyPortablePrivileges,
  normalizePortablePrivileges,
} from './portable-privileges.mjs';

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
const key = encryptionKey();
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
verifyManifestAuthentication(manifest, key);
const portablePrivileges = normalizePortablePrivileges(
  manifest.portablePrivileges,
);
if (
  manifest.format !== 'HDCBKP1' ||
  manifest.manifestVersion !== BACKUP_MANIFEST_VERSION ||
  manifest.encryption !== 'AES-256-GCM' ||
  manifest.source !== 'postgres' ||
  manifest.privilegeMode !== 'authenticated-hdc-allowlist-v1' ||
  JSON.stringify(manifest.excludedExtensions) !==
    JSON.stringify(PORTABLE_BACKUP_EXCLUDED_EXTENSIONS) ||
  JSON.stringify(manifest.excludedSchemas) !==
    JSON.stringify(PORTABLE_BACKUP_EXCLUDED_SCHEMAS) ||
  manifest.backupFile !== backupPath.split(/[\\/]/).at(-1) ||
  !/^[a-f0-9]{64}$/.test(String(manifest.checksumSha256 ?? '')) ||
  !manifest.inventory ||
  !Array.isArray(manifest.inventory.migrationVersions) ||
  manifest.portabilityAudit?.version !== 1 ||
  [
    manifest.portabilityAudit.unknownSchemas,
    manifest.portabilityAudit.unknownExtensions,
    manifest.portabilityAudit.providerReferences,
    manifest.portabilityAudit.nonportablePolicyRoles,
  ].some((value) => !Array.isArray(value) || value.length !== 0) ||
  [
    manifest.portabilityAudit.unvalidatedConstraints,
    manifest.portabilityAudit.invalidIndexes,
    manifest.portabilityAudit.disabledUserTriggers,
    manifest.portabilityAudit.eventTriggers,
    manifest.portabilityAudit.hdcForeignTables,
    manifest.portabilityAudit.hdcPublicationTables,
  ].some((value) => Number(value) !== 0)
) {
  throw new Error('The HDC backup manifest is invalid.');
}

const restoreUrl = process.env.HDC_RESTORE_DATABASE_URL?.trim();
if (!restoreUrl) {
  throw new Error('HDC_RESTORE_DATABASE_URL is required for a full restore rehearsal.');
}
if (process.env.HDC_ALLOW_RESTORE_RESET !== '1') {
  throw new Error('Set HDC_ALLOW_RESTORE_RESET=1 for the isolated restore database.');
}
if (
  process.env.HDC_DATABASE_URL?.trim() &&
  process.env.HDC_DATABASE_URL.trim() === restoreUrl
) {
  throw new Error('The restore database URL must not equal HDC_DATABASE_URL.');
}
const restoreDatabase = decodeURIComponent(
  new URL(restoreUrl).pathname.replace(/^\//, ''),
);
if (!/^hdc[_-]restore(?:[_-].*)?$/i.test(restoreDatabase)) {
  throw new Error('The isolated restore database name must start with hdc_restore.');
}
const checksum = await sha256(backupPath);
if (manifest.checksumSha256 !== checksum) {
  throw new Error('Backup checksum does not match its manifest.');
}

const temporaryDirectory = mkdtempSync(join(tmpdir(), 'hdc-verify-'));
const plainDumpPath = join(temporaryDirectory, 'verified.dump');
try {
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
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

  const restoreSql = postgres(restoreUrl, {
    max: 1,
    prepare: false,
    connect_timeout: 10,
    idle_timeout: 10,
  });
  try {
    await restoreSql.unsafe(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hdc_app') THEN
          CREATE ROLE hdc_app NOLOGIN;
        END IF;
        IF EXISTS (
          SELECT 1 FROM pg_roles
          WHERE rolname = 'hdc_app'
            AND (
              rolcanlogin OR rolsuper OR rolcreaterole OR rolcreatedb OR
              rolreplication OR rolbypassrls
            )
        ) THEN
          RAISE EXCEPTION 'Existing hdc_app role has unsafe attributes';
        END IF;
      END
      $$;
      GRANT hdc_app TO CURRENT_USER WITH SET TRUE;
    `);
  } finally {
    await restoreSql.end({ timeout: 2 });
  }

  const restore = spawnSync(
    'pg_restore',
    [
      '--clean',
      '--if-exists',
      '--no-owner',
      '--no-acl',
      '--exit-on-error',
      '--dbname',
      restoreUrl,
      plainDumpPath,
    ],
    { stdio: ['ignore', 'ignore', 'inherit'] },
  );
  if (restore.error) throw restore.error;
  if (restore.status !== 0) {
    throw new Error(`Full pg_restore failed with exit code ${restore.status}.`);
  }

  const verifiedSql = postgres(restoreUrl, {
    max: 1,
    prepare: false,
    connect_timeout: 10,
    idle_timeout: 10,
  });
  try {
    await applyPortablePrivileges(verifiedSql, portablePrivileges);
    const rows = await verifiedSql`
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
          FROM public.hdc_schema_migrations) AS migration_versions,
        (SELECT count(*)::int FROM public.hdc_legal_documents
          WHERE document_version = 'beta-2026-08-29'
            AND status = 'published') AS legal_documents,
        (SELECT count(*)::int FROM pg_constraint
          WHERE convalidated = false) AS invalid_constraints,
        has_table_privilege(
          'hdc_app', 'public.hdc_service_requests', 'SELECT'
        ) AS app_requests_select,
        has_table_privilege(
          'hdc_app', 'public.hdc_service_transactions', 'SELECT'
        ) AS app_transactions_select,
        has_table_privilege(
          'hdc_app', 'public.hdc_private_messages', 'INSERT'
        ) AS app_messages_insert,
        has_table_privilege(
          'hdc_app', 'public.hdc_service_payments', 'INSERT'
        ) AS app_payments_insert,
        has_table_privilege(
          'hdc_app', 'public.hdc_service_disputes', 'INSERT'
        ) AS app_disputes_insert,
        (SELECT count(*)::int FROM pg_policies
          WHERE schemaname = 'public'
            AND tablename IN (
              'hdc_service_requests', 'hdc_service_transactions',
              'hdc_private_messages', 'hdc_service_payments',
              'hdc_service_disputes'
            )) AS application_policies,
        (SELECT count(*)::int FROM pg_namespace
          WHERE nspname IN ('auth', 'neon_auth', 'pgrst'))
          AS excluded_service_schemas,
        (SELECT count(*)::int
          FROM pg_policies
          WHERE schemaname = 'public'
            AND EXISTS (
              SELECT 1 FROM unnest(roles) policy_role
              WHERE policy_role NOT IN ('public', 'hdc_app')
            )) AS provider_policy_roles,
        (SELECT count(*)::int
          FROM pg_default_acl default_acl
          JOIN pg_roles owner_role ON owner_role.oid = default_acl.defaclrole
          CROSS JOIN LATERAL aclexplode(default_acl.defaclacl) acl
          LEFT JOIN pg_roles grantee_role ON grantee_role.oid = acl.grantee
          WHERE owner_role.rolname IN ('cloud_admin', 'neon_service')
             OR grantee_role.rolname IN ('neon_superuser', 'authenticator'))
          AS provider_default_acl
    `;
    const row = rows[0];
    const restoredInventory = {
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
    if (JSON.stringify(restoredInventory) !== JSON.stringify(manifest.inventory)) {
      throw new Error('Restored row inventory does not match the encrypted backup.');
    }
    if (
      Number(row.legal_documents) !== 2 ||
      Number(row.invalid_constraints) !== 0 ||
      row.app_requests_select !== true ||
      row.app_transactions_select !== true ||
      row.app_messages_insert !== true ||
      row.app_payments_insert !== true ||
      row.app_disputes_insert !== true ||
      Number(row.application_policies) < 5 ||
      Number(row.excluded_service_schemas) !== 0 ||
      Number(row.provider_policy_roles) !== 0 ||
      Number(row.provider_default_acl) !== 0
    ) {
      throw new Error(
        'Restored HDC schema failed legal, constraint, ACL, or RLS readiness checks.',
      );
    }
  } finally {
    await verifiedSql.end({ timeout: 2 });
  }

  console.log(
    'HDC backup decrypted and fully restored; schema and row inventory match.',
  );
} finally {
  rmSync(temporaryDirectory, { recursive: true, force: true });
}
