import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import {
  PORTABLE_BACKUP_EXCLUDED_EXTENSIONS,
  PORTABLE_BACKUP_EXCLUDED_SCHEMAS,
  parseBackupDatabaseUrl,
  pgDumpArguments,
} from '../scripts/postgres/backup-command.mjs';

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

  it('preserves ACLs and verifies restricted application-role access', () => {
    const backup = source('../scripts/postgres/backup.mjs');
    const restore = source('../scripts/postgres/verify-backup.mjs');

    expect(backup).not.toContain("'--no-acl'");
    expect(backup).not.toContain('PGDATABASE: databaseUrl');
    expect(backup).toContain('pgDumpArguments(databaseUrl, plainDumpPath)');
    expect(backup).toContain('manifestVersion: 4');
    expect(backup).toContain('excludedExtensions: [');
    expect(backup).toContain('excludedSchemas: [');
    expect(restore).not.toContain("'--no-acl'");
    expect(restore).toContain('manifest.manifestVersion !== 4');
    expect(restore).toContain('manifest.excludedExtensions');
    expect(restore).toContain('manifest.excludedSchemas');
    expect(restore).toContain("has_table_privilege(");
    expect(restore).toContain("'hdc_app', 'public.hdc_private_messages', 'INSERT'");
    expect(restore).toContain('AS application_policies');
  });
});
