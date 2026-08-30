import { createHash } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import postgres from 'postgres';

const root = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
const migrationDirectory = join(root, 'migrations');

const databaseUrl = process.env.HDC_TEST_DATABASE_URL?.trim();
if (!databaseUrl) {
  throw new Error('HDC_TEST_DATABASE_URL is required for a clean-schema rehearsal.');
}
if (process.env.HDC_ALLOW_TEST_DATABASE_RESET !== '1') {
  throw new Error('Set HDC_ALLOW_TEST_DATABASE_RESET=1 for the isolated test database.');
}
if (
  process.env.HDC_DATABASE_URL?.trim() &&
  process.env.HDC_DATABASE_URL.trim() === databaseUrl
) {
  throw new Error('The test database URL must not equal HDC_DATABASE_URL.');
}

const parsedUrl = new URL(databaseUrl);
const databaseName = decodeURIComponent(parsedUrl.pathname.replace(/^\//, ''));
if (!/^hdc[_-](?:test|restore)(?:[_-].*)?$/i.test(databaseName)) {
  throw new Error(
    'The isolated database name must start with hdc_test or hdc_restore.',
  );
}

const manifest = JSON.parse(
  readFileSync(join(migrationDirectory, 'checksums.json'), 'utf8'),
);
const migrationFiles = readdirSync(migrationDirectory)
  .filter((name) => /^[0-9]{4}_.+\.sql$/.test(name))
  .sort();
if (
  manifest.algorithm !== 'sha256' ||
  JSON.stringify(Object.keys(manifest.files ?? {}).sort()) !==
    JSON.stringify(migrationFiles)
) {
  throw new Error('The migration checksum manifest is incomplete.');
}

const migrations = migrationFiles.map((name) => {
  const contents = readFileSync(join(migrationDirectory, name), 'utf8');
  const checksum = createHash('sha256').update(contents).digest('hex');
  if (checksum !== manifest.files[name]) {
    throw new Error(`Migration checksum mismatch: ${name}`);
  }
  return { name, contents };
});

const sql = postgres(databaseUrl, {
  max: 1,
  prepare: false,
  connect_timeout: 10,
  idle_timeout: 10,
});

try {
  const existing = await sql`
    SELECT count(*)::int AS count
    FROM pg_class table_object
    JOIN pg_namespace namespace ON namespace.oid = table_object.relnamespace
    WHERE namespace.nspname = 'public'
      AND table_object.relname LIKE 'hdc\_%' ESCAPE '\\'
  `;
  if (Number(existing[0]?.count ?? 0) !== 0) {
    throw new Error('Clean-schema rehearsal requires an empty HDC test database.');
  }

  for (const migration of migrations) {
    process.stdout.write(`Applying ${migration.name}... `);
    await sql.unsafe(migration.contents);
    console.log('ok');
  }

  const checks = await sql`
    SELECT
      (SELECT count(*)::int FROM public.hdc_schema_migrations)
        AS migration_count,
      to_regclass('public.hdc_users') IS NOT NULL AS auth_ready,
      to_regclass('public.hdc_service_transactions') IS NOT NULL
        AS transactions_ready,
      to_regclass('public.hdc_private_messages') IS NOT NULL AS chat_ready,
      to_regclass('public.hdc_service_payments') IS NOT NULL AS payments_ready,
      to_regclass('public.hdc_service_disputes') IS NOT NULL AS disputes_ready,
      to_regclass('public.hdc_privacy_requests') IS NOT NULL AS privacy_ready,
      EXISTS (
        SELECT 1 FROM pg_roles
        WHERE rolname = 'hdc_app'
          AND pg_has_role(current_user, oid, 'SET')
      ) AS restricted_role_ready,
      (
        SELECT count(*)::int
        FROM public.hdc_legal_documents
        WHERE document_version = 'beta-2026-08-29'
          AND status = 'published'
      ) AS current_legal_documents
  `;
  const check = checks[0];
  if (
    Number(check.migration_count) !== migrations.length ||
    check.auth_ready !== true ||
    check.transactions_ready !== true ||
    check.chat_ready !== true ||
    check.payments_ready !== true ||
    check.disputes_ready !== true ||
    check.privacy_ready !== true ||
    check.restricted_role_ready !== true ||
    Number(check.current_legal_documents) !== 2
  ) {
    throw new Error(`Clean-schema readiness failed: ${JSON.stringify(check)}`);
  }

  console.log(
    `Clean HDC schema rebuilt from ${migrations.length} verified migrations.`,
  );
} finally {
  await sql.end({ timeout: 2 });
}
