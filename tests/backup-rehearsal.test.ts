import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

function source(path: string): string {
  return readFileSync(fileURLToPath(new URL(path, import.meta.url)), 'utf8');
}

describe('encrypted PostgreSQL restore rehearsal', () => {
  it('preserves ACLs and verifies restricted application-role access', () => {
    const backup = source('../scripts/postgres/backup.mjs');
    const restore = source('../scripts/postgres/verify-backup.mjs');

    expect(backup).not.toContain("'--no-acl'");
    expect(restore).not.toContain("'--no-acl'");
    expect(restore).toContain("has_table_privilege(");
    expect(restore).toContain("'hdc_app', 'public.hdc_private_messages', 'INSERT'");
    expect(restore).toContain('AS application_policies');
  });
});
