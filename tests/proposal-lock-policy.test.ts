import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const migration = readFileSync(
  new URL('../migrations/0011_technician_proposal_lock.sql', import.meta.url),
  'utf8',
);

describe('technician proposal request locking', () => {
  it('permits a technician row lock without permitting row changes', () => {
    expect(migration).toContain(
      'CREATE POLICY hdc_service_requests_technician_lock',
    );
    expect(migration).toContain('FOR UPDATE TO hdc_app');
    expect(migration).toMatch(/hdc_has_role\('technician'\)/);
    expect(migration).toMatch(/WITH CHECK \(false\)/);
  });

  it('limits the lock to open requests owned by another account', () => {
    expect(migration).toContain("status IN ('open', 'receivingOffers')");
    expect(migration).toContain(
      'customer_id <> public.hdc_current_user_id()',
    );
  });
});
