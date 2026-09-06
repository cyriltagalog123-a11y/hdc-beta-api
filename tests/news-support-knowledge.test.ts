import { existsSync, readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const read = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

describe('HDC News, recognition, and Build 26 preparation', () => {
  it('exposes a public read-only news feed', () => {
    const api = read('netlify/functions/news.mts');

    expect(api).toContain("path: '/api/news'");
    expect(api).toContain("if (req.method !== 'GET')");
    expect(api).toContain("WHERE status = 'published'");
    expect(api).toContain('published_at <= now()');
    expect(api).not.toContain('bearerToken');
  });

  it('limits news publishing to owner, super admin, and approved admin', () => {
    const api = read('netlify/functions/news-admin.mts');

    expect(api).toContain("path: '/api/internal/news'");
    expect(api).toContain("new Set(['owner', 'super_admin', 'admin'])");
    expect(api).not.toContain("'moderator'\n");
    expect(api).toContain('news_management_forbidden');
    expect(api).toContain('verifySessionToken');
  });

  it('requires recognition consent in both API and database authority', () => {
    const api = read('netlify/functions/news-admin.mts');
    const migration = read('migrations/0019_public_news_and_recognition.sql');

    expect(api).toContain('recognition_consent_required');
    expect(api).toContain('recognitionConsentConfirmed');
    expect(migration).toContain('hdc_public_news_recognition_consent');
    expect(migration).toContain('recognition_consent_confirmed = true');
  });

  it('audits public publishing changes', () => {
    const api = read('netlify/functions/news-admin.mts');

    expect(api).toContain("'news.create'");
    expect(api).toContain("'news.update'");
    expect(api).toContain("'news.delete'");
    expect(api).toContain('hdc_security_audit');
  });

  it('provides owner/admin publishing UI without code edits', () => {
    const manager = read('lib/features/news/news_management_screen.dart');
    const provider = read('lib/providers/hdc_news_provider.dart');

    expect(manager).toContain('Publish without touching code.');
    expect(manager).toContain('Public recognition consent confirmed');
    expect(manager).toContain('Save & Publish');
    expect(provider).toContain('HDCInternalRole.owner');
    expect(provider).toContain('HDCInternalRole.superAdmin');
    expect(provider).toContain('HDCInternalRole.admin');
  });

  it('makes News and the Knowledge Base shell public navigation destinations', () => {
    const dashboard = read('lib/features/dashboard/dashboard_screen.dart');

    expect(dashboard).toContain("label: 'HDC News'");
    expect(dashboard).toContain("label: 'Knowledge Base'");
    expect(dashboard).toContain('NewsScreen');
    expect(dashboard).toContain('KnowledgeBaseScreen');
  });

  it('keeps Knowledge Base implementation explicitly deferred to Build 26', () => {
    const kb = read('lib/features/knowledge_base/knowledge_base_screen.dart');

    expect(kb).toContain('BUILD 26 READY');
    expect(kb).toContain('Search becomes active in Build 26');
    expect(kb).toContain('enabled: false');
    expect(kb).toContain('Nexus knowledge retrieval foundation');
    expect(kb).toContain('does not fabricate articles, search results, or Nexus answers');
  });

  it('does not leave temporary one-shot patch machinery in the review branch', () => {
    const root = new URL('../', import.meta.url);
    expect(existsSync(new URL('scripts/wire_news_and_knowledge_shell.py', root))).toBe(false);
    expect(existsSync(new URL('.github/workflows/wire-news-and-knowledge-shell.yml', root))).toBe(false);
  });
});
