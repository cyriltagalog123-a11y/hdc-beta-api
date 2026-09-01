import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import {
  authenticateManifest,
  BACKUP_MANIFEST_VERSION,
  verifyManifestAuthentication,
} from '../scripts/postgres/backup-format.mjs';
import {
  PORTABLE_BACKUP_EXCLUDED_EXTENSIONS,
  PORTABLE_BACKUP_EXCLUDED_SCHEMAS,
  parseBackupDatabaseUrl,
  pgDumpArguments,
} from '../scripts/postgres/backup-command.mjs';
import {
  normalizePortablePrivileges,
  renderPortablePrivilegeStatements,
} from '../scripts/postgres/portable-privileges.mjs';

function source(path: string): string {
  return readFileSync(fileURLToPath(new URL(path, import.meta.url)), 'utf8');
}

describe('encrypted PostgreSQL restore rehearsal', () => {
  it('passes a direct PostgreSQL URL explicitly to pg_dump', () => {
    const databaseUrl =
      'postgresql://hdc@ep-hdc-backup.us-east-2.aws.neon.tech/hdc?sslmode=require';
    const outputPath = '/tmp/hdc-postgres.dump';

    expect(parseBackupDatabaseUrl(databaseUrl).hostname).toBe(
      'ep-hdc-backup.us-east-2.aws.neon.tech',
    );
    expect(pgDumpArguments(databaseUrl, outputPath)).toEqual([
      '--dbname',
      databaseUrl,
      '--format=custom',
      '--no-owner',
      '--no-acl',
      '--no-password',
      '--exclude-extension=pg_session_jwt',
      '--exclude-schema=auth',
      '--exclude-schema=neon_auth',
      '--exclude-schema=pgrst',
      '--file',
      outputPath,
    ]);
  });

  it('excludes Neon service metadata but retains HDC extensions', () => {
    const arguments_ = pgDumpArguments(
      'postgresql://hdc@ep-hdc-backup.us-east-2.aws.neon.tech/hdc',
      '/tmp/hdc-postgres.dump',
    );

    expect(PORTABLE_BACKUP_EXCLUDED_EXTENSIONS).toEqual(['pg_session_jwt']);
    expect(PORTABLE_BACKUP_EXCLUDED_SCHEMAS).toEqual([
      'auth',
      'neon_auth',
      'pgrst',
    ]);
    expect(arguments_).toContain('--exclude-extension=pg_session_jwt');
    expect(arguments_).toContain('--exclude-schema=auth');
    expect(arguments_).toContain('--exclude-schema=neon_auth');
    expect(arguments_).toContain('--exclude-schema=pgrst');
    expect(arguments_).not.toContain('--exclude-extension=pgcrypto');
    expect(arguments_).not.toContain('--exclude-extension=citext');
  });

  it('rejects a pooled Neon URL for pg_dump', () => {
    const pooledUrl =
      'postgresql://hdc@ep-hdc-backup-pooler.us-east-2.aws.neon.tech/hdc';

    expect(() => parseBackupDatabaseUrl(pooledUrl)).toThrow(
      'direct (unpooled) PostgreSQL connection',
    );
  });

  it('authenticates the privilege manifest and rejects tampering', () => {
    const key = Buffer.alloc(32, 7);
    const authenticated = authenticateManifest({
      format: 'HDCBKP1',
      manifestVersion: BACKUP_MANIFEST_VERSION,
      portablePrivileges: { version: 1, objects: [] },
    }, key);

    expect(verifyManifestAuthentication(authenticated, key)).toEqual({
      format: 'HDCBKP1',
      manifestVersion: BACKUP_MANIFEST_VERSION,
      portablePrivileges: { version: 1, objects: [] },
    });
    expect(() => verifyManifestAuthentication({
      ...authenticated,
      manifestVersion: 999,
    }, key)).toThrow('authentication failed');
  });

  it('renders only allow-listed HDC and PUBLIC privileges', () => {
    const snapshot = normalizePortablePrivileges({
      version: 1,
      objects: [
        {
          kind: 'SCHEMA',
          schema: 'public',
          name: 'public',
          grants: [
            { grantee: 'PUBLIC', privilege: 'USAGE', grantable: false },
            { grantee: 'hdc_app', privilege: 'USAGE', grantable: false },
          ],
        },
        {
          kind: 'TABLE',
          schema: 'public',
          name: 'hdc_schema_migrations',
          grants: [],
        },
        {
          kind: 'TABLE',
          schema: 'public',
          name: 'hdc_users',
          grants: [],
        },
        {
          kind: 'FUNCTION',
          schema: 'public',
          name: 'hdc_current_user_id',
          grants: [
            { grantee: 'hdc_app', privilege: 'EXECUTE', grantable: false },
          ],
        },
        {
          kind: 'DOMAIN',
          schema: 'public',
          name: 'hdc_positive_amount',
          grants: [
            { grantee: 'PUBLIC', privilege: 'USAGE', grantable: false },
          ],
        },
      ],
    });
    const statements = renderPortablePrivilegeStatements(snapshot);

    expect(statements).toContain(
      'REVOKE ALL PRIVILEGES ON FUNCTION "public".' +
      '"hdc_current_user_id"() FROM PUBLIC, "hdc_app";',
    );
    expect(statements).toContain(
      'GRANT EXECUTE ON FUNCTION "public".' +
      '"hdc_current_user_id"() TO "hdc_app";',
    );
    expect(statements).toContain(
      'GRANT USAGE ON DOMAIN "public"."hdc_positive_amount" TO PUBLIC;',
    );
    expect(statements.join('\n')).not.toMatch(
      /cloud_admin|neon_superuser|neondb_owner|authenticator/,
    );
  });

  it('excludes provider ACLs and verifies restricted application access', () => {
    const backup = source('../scripts/postgres/backup.mjs');
    const restore = source('../scripts/postgres/verify-backup.mjs');

    expect(pgDumpArguments(
      'postgresql://hdc@ep-hdc-backup.us-east-2.aws.neon.tech/hdc',
      '/tmp/hdc-postgres.dump',
    )).toContain('--no-acl');
    expect(backup).not.toContain('PGDATABASE: databaseUrl');
    expect(backup).toContain('pgDumpArguments(databaseUrl, plainDumpPath)');
    expect(backup).toContain('manifestVersion: BACKUP_MANIFEST_VERSION');
    expect(backup).toContain("privilegeMode: 'authenticated-hdc-allowlist-v1'");
    expect(backup).toContain('excludedExtensions: [');
    expect(backup).toContain('excludedSchemas: [');
    expect(restore).toContain("'--no-acl'");
    expect(restore).toContain('applyPortablePrivileges(');
    expect(restore).toContain(
      'manifest.manifestVersion !== BACKUP_MANIFEST_VERSION',
    );
    expect(restore).toContain('manifest.excludedExtensions');
    expect(restore).toContain('manifest.excludedSchemas');
    expect(restore).toContain("has_table_privilege(");
    expect(restore).toContain("'hdc_app', 'public.hdc_private_messages', 'INSERT'");
    expect(restore).toContain('AS application_policies');
  });
});
