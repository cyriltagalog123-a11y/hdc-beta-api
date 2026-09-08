import { readFile } from 'node:fs/promises';
import { describe, expect, it } from 'vitest';

const read = (path: string) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

describe('Build 27 Knowledge Base release contract', () => {
  it('activates public search, safety guidance, feedback, and service handoff', async () => {
    const screen = await read('lib/features/knowledge_base/knowledge_base_screen.dart');
    const article = await read('lib/features/knowledge_base/knowledge_article_screen.dart');
    const client = await read('lib/core/api/hdc_workflow_api_client.dart');

    expect(screen).toContain('BUILD 27 • LIVE KNOWLEDGE');
    expect(screen).toContain('Search the HDC Knowledge Base');
    expect(screen).toContain('Manage Knowledge');
    expect(article).toContain('Safety boundary');
    expect(article).toContain('When to stop and escalate');
    expect(article).toContain('Did this guide help?');
    expect(article).toContain('Still need help? Post a request');
    expect(article).toContain('CreateServiceRequestScreen(initialDraft: draft)');
    expect(client).toContain("'knowledge_version_conflict'");
    expect(client).toContain("'knowledge_slug_conflict'");
  });

  it('grounds Nexus only in published HDC knowledge', async () => {
    const api = await read('netlify/functions/knowledge.mts');

    expect(api).toContain("authority: 'hdc_published_knowledge'");
    expect(api).toContain('generationAllowed: false');
    expect(api).toContain('version.version = article.published_version');
    expect(api).toContain('version.nexus_ready = true');
    expect(api).toContain('authorizeMemberRequest(req, sql)');
  });

  it('separates authoring from publication and retains published history', async () => {
    const admin = await read('netlify/functions/knowledge-admin.mts');
    const migration = await read('migrations/0023_build27_knowledge_base.sql');
    const slugLock = await read('migrations/0024_build27_knowledge_slug_stability.sql');
    const cleanSchema = await read('scripts/postgres/rehearse-clean-schema.mjs');
    const upgrade = await read('scripts/postgres/rehearse-build27-upgrade.mjs');
    const ci = await read('.github/workflows/ci.yml');

    expect(admin).toContain("const writerRoles = new Set(['owner', 'super_admin', 'admin'])");
    expect(admin).toContain("const publisherRoles = new Set(['owner', 'super_admin'])");
    expect(admin).toContain("error: 'knowledge_publish_forbidden'");
    expect(admin).toContain("error: 'knowledge_version_conflict'");
    expect(admin).toContain(".code === '23505'");
    expect(admin).toContain('FOR UPDATE');
    expect(admin).toContain('published_version = CASE');
    expect(admin).toContain('Only never-published drafts or review copies can be deleted');
    expect(migration).toContain('hdc_knowledge_article_versions');
    expect(migration).toContain('hdc_knowledge_feedback');
    expect(migration).toContain('KB-POS-001');
    expect(migration).toContain("VALUES ('0023', 'build27_knowledge_base', false)");
    expect(migration).toContain('ON public.hdc_knowledge_article_versions TO hdc_app');
    expect(slugLock).toContain('Published HDC knowledge slugs are permanent');
    expect(slugLock).toContain('Published HDC knowledge history must be archived and retained');
    expect(slugLock).toContain('HDC knowledge article versions are immutable');
    expect(slugLock).toContain("VALUES ('0024', 'build27_knowledge_slug_stability', false)");
    expect(cleanSchema).toContain('AS knowledge_ready');
    expect(cleanSchema).toContain('AS knowledge_protection_triggers');
    expect(upgrade).toContain('Representative legacy request');
    expect(upgrade).toContain('migrations 0017-0024');
    expect(ci).toContain('npm run db:rehearse-build27-upgrade');
  });
});
