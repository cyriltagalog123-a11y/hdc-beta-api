import postgres from 'postgres';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { handleHdcApiRequest } from '../netlify/functions/api.mjs';
import knowledgeHandler from '../netlify/functions/knowledge.mjs';
import knowledgeAdminHandler from '../netlify/functions/knowledge-admin.mjs';

const runPostgresIntegration = process.env.HDC_POSTGRES_INTEGRATION === '1';

type TestAccount = {
  id: string;
  email: string;
  password: string;
  token: string;
};

type ApiResult = {
  response: Response;
  body: Record<string, unknown>;
};

let sql: ReturnType<typeof postgres> | null = null;
let owner: TestAccount;
let admin: TestAccount;
let member: TestAccount;
let sequence = 0;
let workingArticle: Record<string, unknown>;

function nextRef(prefix: string): string {
  sequence += 1;
  return `${prefix}-${Date.now()}-${sequence}`;
}

async function parse(response: Response): Promise<ApiResult> {
  return {
    response,
    body: await response.json() as Record<string, unknown>,
  };
}

async function mainApi(path: string, init: RequestInit = {}, token?: string) {
  return parse(await handleHdcApiRequest(new Request(`https://hdc-kb.test${path}`, {
    ...init,
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(init.headers ?? {}),
    },
  })));
}

async function publicKnowledge(path: string, init: RequestInit = {}, token?: string) {
  return parse(await knowledgeHandler(new Request(`https://hdc-kb.test${path}`, {
    ...init,
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(init.headers ?? {}),
    },
  })));
}

async function adminKnowledge(path: string, init: RequestInit = {}, token?: string) {
  return parse(await knowledgeAdminHandler(new Request(`https://hdc-kb.test${path}`, {
    ...init,
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(init.headers ?? {}),
    },
  })));
}

function expectStatus(result: ApiResult, status: number): void {
  expect(result.response.status, JSON.stringify(result.body)).toBe(status);
}

async function register(label: string): Promise<Omit<TestAccount, 'token'>> {
  const slug = label.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  const email = `${slug}-${nextRef('kb').toLowerCase()}@example.invalid`;
  const password = 'Build27!Knowledge-Test-4829';
  const result = await mainApi('/api/auth/register', {
    method: 'POST',
    body: JSON.stringify({
      email,
      password,
      displayName: `HDC ${label}`,
      location: 'Cebu City, Central Visayas, Philippines',
      recoveryAnswers: [
        { questionCode: 'first_meal', answer: `${label} warm rice` },
        { questionCode: 'childhood_nickname', answer: `${label} blue comet` },
        { questionCode: 'private_phrase', answer: `${label} safe harbor` },
      ],
      termsAccepted: true,
      privacyAcknowledged: true,
      termsVersion: 'beta-2026-09-06',
    }),
  });
  expectStatus(result, 201);
  return {
    id: String((result.body.user as Record<string, unknown>).id),
    email,
    password,
  };
}

async function login(account: Omit<TestAccount, 'token'>): Promise<TestAccount> {
  const result = await mainApi('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email: account.email, password: account.password }),
  });
  expectStatus(result, 200);
  return { ...account, token: String(result.body.token) };
}

const basePayload = {
  title: 'Build 27 controlled network troubleshooting guide',
  slug: 'build27-controlled-network-guide',
  category: 'network_internet',
  summary: 'A controlled Build 27 guide used to verify knowledge review and publication rules.',
  body: 'Use this regression guide only to verify that HDC separates working knowledge from the currently published public version.',
  steps: [
    'Confirm the affected device and network before changing any configuration.',
    'Compare the result with another device on the same authorized network.',
  ],
  tags: ['build27', 'network', 'regression'],
  safetyLevel: 'moderate',
  safetyNotice: 'Do not change shared router or business network configuration without authorization.',
  escalationText: 'Escalate when multiple devices are affected or the network supports active business operations.',
  nexusReady: true,
  isFeatured: false,
  changeNote: 'Build 27 integration coverage',
};

describe.skipIf(!runPostgresIntegration).sequential(
  'Build 27 versioned Knowledge Base',
  () => {
    beforeAll(async () => {
      const databaseUrl = process.env.HDC_DATABASE_URL;
      if (!databaseUrl) throw new Error('HDC_DATABASE_URL is required.');
      sql = postgres(databaseUrl, { max: 4, prepare: false });

      const rawOwner = await register('Knowledge Owner');
      const rawAdmin = await register('Knowledge Admin');
      const rawMember = await register('Knowledge Member');

      await sql`
        INSERT INTO public.hdc_internal_role_assignments(
          user_id, role, is_active, assignment_note
        ) VALUES
          (${rawOwner.id}::uuid, 'owner', true, 'Build 27 publication regression'),
          (${rawAdmin.id}::uuid, 'admin', true, 'Build 27 authoring regression')
        ON CONFLICT(user_id, role) DO UPDATE SET is_active = true
      `;

      owner = await login(rawOwner);
      admin = await login(rawAdmin);
      member = await login(rawMember);
    }, 90_000);

    afterAll(async () => {
      await sql?.end({ timeout: 2 });
      sql = null;
    });

    it('publishes only reviewed starter knowledge and gives Nexus retrieval no generation authority', async () => {
      const search = await publicKnowledge('/api/knowledge?q=POS');
      expectStatus(search, 200);
      const articles = search.body.articles as Record<string, unknown>[];
      expect(articles.some((article) => article.publicArticleId === 'KB-POS-001')).toBe(true);

      const detail = await publicKnowledge('/api/knowledge?slug=pos-unable-to-locate-server');
      expectStatus(detail, 200);
      const article = detail.body.article as Record<string, unknown>;
      expect(article.safetyLevel).toBe('moderate');
      expect(Array.isArray(article.steps)).toBe(true);
      expect(String(article.escalationText)).toContain('multiple terminals');

      const nexus = await publicKnowledge('/api/knowledge?mode=nexus&q=server');
      expectStatus(nexus, 200);
      expect(nexus.body.authority).toBe('hdc_published_knowledge');
      expect(nexus.body.generationAllowed).toBe(false);
      const retrievals = nexus.body.retrievals as Record<string, unknown>[];
      expect(retrievals.length).toBeGreaterThan(0);
      expect(retrievals.every((item) => item.nexusReady === true)).toBe(true);
    });

    it('lets Admin draft/review but reserves publication for Owner or Super Admin', async () => {
      const unsafe = await adminKnowledge('/api/internal/knowledge', {
        method: 'POST',
        body: JSON.stringify({
          ...basePayload,
          title: 'High risk guide missing boundaries',
          slug: 'high-risk-missing-boundaries',
          safetyLevel: 'high',
          safetyNotice: '',
          escalationText: '',
          status: 'draft',
        }),
      }, admin.token);
      expectStatus(unsafe, 400);
      expect(unsafe.body.error).toBe('knowledge_safety_notice_required');

      const created = await adminKnowledge('/api/internal/knowledge', {
        method: 'POST',
        body: JSON.stringify({ ...basePayload, status: 'review' }),
      }, admin.token);
      expectStatus(created, 201);
      workingArticle = created.body.article as Record<string, unknown>;
      expect(workingArticle.status).toBe('review');
      expect(workingArticle.publicVisible).toBe(false);

      const hidden = await publicKnowledge('/api/knowledge?q=controlled%20network%20troubleshooting');
      expectStatus(hidden, 200);
      expect((hidden.body.articles as Record<string, unknown>[])
        .some((article) => article.publicArticleId === workingArticle.publicArticleId))
        .toBe(false);

      const deniedPublish = await adminKnowledge('/api/internal/knowledge', {
        method: 'PUT',
        body: JSON.stringify({
          ...basePayload,
          id: workingArticle.id,
          status: 'published',
        }),
      }, admin.token);
      expectStatus(deniedPublish, 403);
      expect(deniedPublish.body.error).toBe('knowledge_publish_forbidden');
    });

    it('keeps the last published version public while a newer review version is being edited', async () => {
      const published = await adminKnowledge('/api/internal/knowledge', {
        method: 'PUT',
        body: JSON.stringify({
          ...basePayload,
          id: workingArticle.id,
          status: 'published',
          changeNote: 'Owner approves first public version',
        }),
      }, owner.token);
      expectStatus(published, 200);
      workingArticle = published.body.article as Record<string, unknown>;
      expect(workingArticle.version).toBe(2);
      expect(workingArticle.publishedVersion).toBe(2);

      const publicV2 = await publicKnowledge(`/api/knowledge?slug=${basePayload.slug}`);
      expectStatus(publicV2, 200);
      expect((publicV2.body.article as Record<string, unknown>).version).toBe(2);
      expect((publicV2.body.article as Record<string, unknown>).title).toBe(basePayload.title);

      const reviewTitle = 'Build 27 controlled network guide awaiting republish';
      const review = await adminKnowledge('/api/internal/knowledge', {
        method: 'PUT',
        body: JSON.stringify({
          ...basePayload,
          id: workingArticle.id,
          title: reviewTitle,
          status: 'review',
          changeNote: 'Admin prepares a newer review version',
        }),
      }, admin.token);
      expectStatus(review, 200);
      workingArticle = review.body.article as Record<string, unknown>;
      expect(workingArticle.version).toBe(3);
      expect(workingArticle.publishedVersion).toBe(2);
      expect(workingArticle.publicVisible).toBe(true);

      const stillV2 = await publicKnowledge(`/api/knowledge?slug=${basePayload.slug}`);
      expectStatus(stillV2, 200);
      expect((stillV2.body.article as Record<string, unknown>).version).toBe(2);
      expect((stillV2.body.article as Record<string, unknown>).title).toBe(basePayload.title);

      await expect(sql!`
        UPDATE public.hdc_knowledge_articles
        SET slug = 'attempt-to-break-published-link'
        WHERE id = ${String(workingArticle.id)}::uuid
      `).rejects.toThrow(/slugs are permanent/i);
    });

    it('publishes a newer version, tracks member feedback by version, and retains history after archive', async () => {
      const finalTitle = 'Build 27 controlled network guide approved update';
      const republished = await adminKnowledge('/api/internal/knowledge', {
        method: 'PUT',
        body: JSON.stringify({
          ...basePayload,
          id: workingArticle.id,
          title: finalTitle,
          status: 'published',
          changeNote: 'Owner publishes reviewed update',
        }),
      }, owner.token);
      expectStatus(republished, 200);
      workingArticle = republished.body.article as Record<string, unknown>;
      expect(workingArticle.version).toBe(4);
      expect(workingArticle.publishedVersion).toBe(4);

      const current = await publicKnowledge(`/api/knowledge?slug=${basePayload.slug}`);
      expectStatus(current, 200);
      expect((current.body.article as Record<string, unknown>).title).toBe(finalTitle);
      expect((current.body.article as Record<string, unknown>).version).toBe(4);

      const guestFeedback = await publicKnowledge('/api/knowledge', {
        method: 'POST',
        body: JSON.stringify({
          publicArticleId: workingArticle.publicArticleId,
          version: 4,
          helpful: true,
        }),
      });
      expectStatus(guestFeedback, 401);

      const helpful = await publicKnowledge('/api/knowledge', {
        method: 'POST',
        body: JSON.stringify({
          publicArticleId: workingArticle.publicArticleId,
          version: 4,
          helpful: true,
          note: 'The published guide was clear.',
        }),
      }, member.token);
      expectStatus(helpful, 200);
      expect(helpful.body.helpfulCount).toBe(1);

      const changedOpinion = await publicKnowledge('/api/knowledge', {
        method: 'POST',
        body: JSON.stringify({
          publicArticleId: workingArticle.publicArticleId,
          version: 4,
          helpful: false,
          note: 'A later check showed one step needs more detail.',
        }),
      }, member.token);
      expectStatus(changedOpinion, 200);
      expect(changedOpinion.body.helpfulCount).toBe(0);
      expect(changedOpinion.body.notHelpfulCount).toBe(1);

      const stale = await publicKnowledge('/api/knowledge', {
        method: 'POST',
        body: JSON.stringify({
          publicArticleId: workingArticle.publicArticleId,
          version: 2,
          helpful: true,
        }),
      }, member.token);
      expectStatus(stale, 409);
      expect(stale.body.error).toBe('knowledge_article_version_changed');

      const deletePublished = await adminKnowledge(
        `/api/internal/knowledge?id=${workingArticle.id}`,
        { method: 'DELETE' },
        owner.token,
      );
      expectStatus(deletePublished, 409);
      expect(deletePublished.body.error).toBe('knowledge_delete_not_allowed');

      const archived = await adminKnowledge('/api/internal/knowledge', {
        method: 'PUT',
        body: JSON.stringify({
          ...basePayload,
          id: workingArticle.id,
          title: finalTitle,
          status: 'archived',
          changeNote: 'Archive while retaining publication history',
        }),
      }, owner.token);
      expectStatus(archived, 200);
      workingArticle = archived.body.article as Record<string, unknown>;
      expect(workingArticle.status).toBe('archived');

      const hidden = await publicKnowledge(`/api/knowledge?slug=${basePayload.slug}`);
      expectStatus(hidden, 404);

      const history = await adminKnowledge(
        `/api/internal/knowledge?view=history&id=${workingArticle.id}`,
        {},
        owner.token,
      );
      expectStatus(history, 200);
      const versions = history.body.versions as Record<string, unknown>[];
      expect(versions.length).toBe(5);
      expect(versions[0].workflowStatus).toBe('archived');
      expect(versions.some((version) => version.workflowStatus === 'published')).toBe(true);
    });
  },
);
