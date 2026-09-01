import { spawnSync } from 'node:child_process';
import {
  mkdtempSync,
  readdirSync,
  rmSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import postgres from 'postgres';

import { capturePortablePrivileges } from './portable-privileges.mjs';

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function databaseName(databaseUrl) {
  return decodeURIComponent(new URL(databaseUrl).pathname.replace(/^\//, ''));
}

function runScript(script, arguments_) {
  const result = spawnSync(
    process.execPath,
    [script, ...arguments_],
    { env: { ...process.env }, stdio: 'inherit' },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${script} failed with exit code ${result.status}.`);
  }
}

const sourceUrl = required('HDC_DATABASE_URL');
const restoreUrl = required('HDC_RESTORE_DATABASE_URL');
required('HDC_BACKUP_ENCRYPTION_KEY');
if (process.env.HDC_ALLOW_RESTORE_RESET !== '1') {
  throw new Error('Set HDC_ALLOW_RESTORE_RESET=1 for the isolated restore cluster.');
}
if (!/^hdc_test(?:[_-].*)?$/i.test(databaseName(sourceUrl))) {
  throw new Error('The source integration database must start with hdc_test.');
}
if (!/^hdc_restore(?:[_-].*)?$/i.test(databaseName(restoreUrl))) {
  throw new Error('The restore integration database must start with hdc_restore.');
}
if (sourceUrl === restoreUrl) {
  throw new Error('Backup integration requires separate source and restore clusters.');
}

const sourceSql = postgres(sourceUrl, {
  max: 1,
  prepare: false,
  connect_timeout: 10,
  idle_timeout: 10,
});
let sourcePrivileges;
try {
  await sourceSql.unsafe(`
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cloud_admin') THEN
        CREATE ROLE cloud_admin NOLOGIN;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'neon_superuser') THEN
        CREATE ROLE neon_superuser NOLOGIN;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'neondb_owner') THEN
        CREATE ROLE neondb_owner NOLOGIN;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'neon_service') THEN
        CREATE ROLE neon_service NOLOGIN;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator NOLOGIN;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anonymous') THEN
        CREATE ROLE anonymous NOLOGIN;
      END IF;
    END
    $$;

    CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION neon_service;
    CREATE SCHEMA IF NOT EXISTS neon_auth AUTHORIZATION neon_service;
    CREATE SCHEMA IF NOT EXISTS pgrst AUTHORIZATION neon_service;
    CREATE TABLE IF NOT EXISTS auth.provider_identity (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid()
    );
    CREATE TABLE IF NOT EXISTS neon_auth.provider_session (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid()
    );
    CREATE OR REPLACE FUNCTION pgrst.pre_config()
    RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN NULL; END $$;
    GRANT USAGE ON SCHEMA pgrst TO authenticator;
    GRANT EXECUTE ON FUNCTION pgrst.pre_config() TO authenticator;

    ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public
      GRANT ALL ON TABLES TO neon_superuser WITH GRANT OPTION;
    ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public
      GRANT ALL ON SEQUENCES TO neon_superuser WITH GRANT OPTION;

    DROP TABLE IF EXISTS public.hdc_portability_probe;
    CREATE TABLE public.hdc_portability_probe (
      id integer PRIMARY KEY,
      value text NOT NULL
    );
    ALTER TABLE public.hdc_portability_probe OWNER TO neondb_owner;
    GRANT SELECT, INSERT ON public.hdc_portability_probe TO hdc_app;
    GRANT SELECT ON public.hdc_portability_probe TO authenticator;
    INSERT INTO public.hdc_portability_probe (id, value)
    VALUES (1, 'portable-provider-metadata-probe');

    CREATE OR REPLACE FUNCTION public.hdc_portability_probe_function()
    RETURNS text
    LANGUAGE sql
    IMMUTABLE
    AS $$ SELECT 'portable'::text $$;
    ALTER FUNCTION public.hdc_portability_probe_function()
      OWNER TO neondb_owner;
    REVOKE ALL ON FUNCTION public.hdc_portability_probe_function() FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.hdc_portability_probe_function()
      TO hdc_app;
    GRANT EXECUTE ON FUNCTION public.hdc_portability_probe_function()
      TO authenticator;
  `);
  sourcePrivileges = await capturePortablePrivileges(sourceSql);
} finally {
  await sourceSql.end({ timeout: 2 });
}

const outputDirectory = mkdtempSync(join(tmpdir(), 'hdc-backup-integration-'));
try {
  runScript('scripts/postgres/backup.mjs', ['--output', outputDirectory]);
  const backupFile = readdirSync(outputDirectory)
    .find((name) => name.endsWith('.hdcbackup'));
  if (!backupFile) throw new Error('The integration backup file was not created.');
  runScript('scripts/postgres/verify-backup.mjs', [
    '--backup',
    join(outputDirectory, backupFile),
  ]);

  const restoreSql = postgres(restoreUrl, {
    max: 1,
    prepare: false,
    connect_timeout: 10,
    idle_timeout: 10,
  });
  try {
    const restoredPrivileges = await capturePortablePrivileges(restoreSql);
    if (JSON.stringify(restoredPrivileges) !== JSON.stringify(sourcePrivileges)) {
      throw new Error('Integration restore changed the HDC privilege contract.');
    }
    const checks = await restoreSql`
      SELECT
        (SELECT count(*)::int FROM public.hdc_portability_probe
          WHERE id = 1 AND value = 'portable-provider-metadata-probe')
          AS probe_rows,
        (SELECT count(*)::int FROM pg_namespace
          WHERE nspname IN ('auth', 'neon_auth', 'pgrst'))
          AS provider_schemas,
        (SELECT count(*)::int FROM pg_roles
          WHERE rolname IN (
            'cloud_admin', 'neon_superuser', 'neondb_owner', 'neon_service',
            'authenticator', 'authenticated', 'anonymous'
          )) AS provider_roles,
        has_table_privilege(
          'hdc_app', 'public.hdc_portability_probe', 'SELECT'
        ) AS app_probe_select,
        has_table_privilege(
          'hdc_app', 'public.hdc_portability_probe', 'INSERT'
        ) AS app_probe_insert,
        has_function_privilege(
          'hdc_app', 'public.hdc_portability_probe_function()', 'EXECUTE'
        ) AS app_probe_execute,
        (SELECT count(*)::int
          FROM pg_proc procedure
          JOIN pg_namespace namespace ON namespace.oid = procedure.pronamespace
          CROSS JOIN LATERAL aclexplode(COALESCE(
            procedure.proacl,
            acldefault('f', procedure.proowner)
          )) acl
          WHERE namespace.nspname = 'public'
            AND procedure.proname = 'hdc_portability_probe_function'
            AND acl.grantee = 0
            AND acl.privilege_type = 'EXECUTE') AS public_probe_execute
    `;
    const check = checks[0];
    if (
      Number(check.probe_rows) !== 1 ||
      Number(check.provider_schemas) !== 0 ||
      Number(check.provider_roles) !== 0 ||
      check.app_probe_select !== true ||
      check.app_probe_insert !== true ||
      check.app_probe_execute !== true ||
      Number(check.public_probe_execute) !== 0
    ) {
      throw new Error(
        `Production-shaped restore checks failed: ${JSON.stringify(check)}`,
      );
    }
  } finally {
    await restoreSql.end({ timeout: 2 });
  }

  console.log(
    'Production-shaped encrypted backup restored on a provider-neutral cluster.',
  );
} finally {
  rmSync(outputDirectory, { recursive: true, force: true });
}
