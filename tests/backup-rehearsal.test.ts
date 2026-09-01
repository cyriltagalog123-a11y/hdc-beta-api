import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import {
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
      '--file',
      outputPath,
    ]);
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
    expect(restore).not.toContain("'--no-acl'");
    expect(restore).toContain("has_table_privilege(");
    expect(restore).toContain("'hdc_app', 'public.hdc_private_messages', 'INSERT'");
    expect(restore).toContain('AS application_policies');
  });
});
