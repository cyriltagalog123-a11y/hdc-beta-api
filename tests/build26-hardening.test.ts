import { describe, expect, it } from 'vitest';
import { readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const read = (path: string) => readFile(new URL(path, root), 'utf8');

describe('Build 26 hardening contract', () => {
  it('uses one permanent controlled-location registration contract', async () => {
    const gateway = await read('lib/core/auth/hdc_api_auth_gateway.dart');
    const registration = await read('netlify/functions/_lib/registration.mts');
    const alias = await read('netlify/functions/register-v2.mts');
    expect(gateway).toContain("'/api/auth/register'");
    expect(registration).toContain('normalizeHdcLocation');
    expect(registration).toContain("operationMode() !== 'normal'");
    expect(alias).toContain("deprecation', 'true'");
    expect(alias).toContain('</api/auth/register>');
  });

  it('keeps CI read-only and Netlify responsible for source-built Flutter web', async () => {
    const ci = await read('.github/workflows/ci.yml');
    const netlify = await read('netlify.toml');
    expect(ci).not.toContain('git push origin');
    expect(ci).not.toContain('contents: write');
    expect(ci).toContain('npm audit --omit=dev --audit-level=high');
    expect(netlify).toContain('bash scripts/netlify-build.sh');
  });

  it('retains published News and requires richer recognition consent evidence', async () => {
    const migration = await read('migrations/0020_build26_news_consent_history.sql');
    const admin = await read('netlify/functions/news-admin.mts');
    expect(migration).toContain('ever_published');
    expect(migration).toContain('recognition_consent_method');
    expect(migration).toContain('Published HDC news history must be archived and retained');
    expect(admin).toContain('recognitionConsentScope');
    expect(admin).toContain('ever_published = false');
    expect(admin).toContain('recognition_consent_at');
    expect(admin).toContain('recognition_consent_reference');
  });

  it('moves real Knowledge Base implementation to Build 27', async () => {
    const kb = await read('lib/features/knowledge_base/knowledge_base_screen.dart');
    expect(kb).toContain('BUILD 27 READY');
    expect(kb).toContain('implemented in Build 27');
    expect(kb).not.toContain('Search becomes active in Build 26');
  });

  it('publishes the current legal revision and latest-schema readiness', async () => {
    const legal = await read('netlify/functions/_lib/legal-documents.mts');
    const api = await read('netlify/functions/api.mts');
    expect(legal).toContain("CURRENT_LEGAL_VERSION = 'beta-2026-09-06'");
    expect(api).toContain("version = '0021'");
    expect(api).toContain("build: '0.6.4-build26'");
  });
});
