import { randomBytes } from 'node:crypto';

import { openDb, closeDb, type DbClient } from './_lib/db.mjs';
import { corsPreflightResponse, withCors } from './_lib/cors.mjs';
import { json, methodNotAllowed, readJson } from './_lib/http.mjs';
import { operationMode } from './_lib/env.mjs';
import { authorizeMemberRequest } from './_lib/member-auth.mjs';

const categories = new Set([
  'pc_laptop',
  'phones_mobile',
  'pos_business_tech',
  'network_internet',
  'printers_peripherals',
  'security_accounts',
]);

function cleanText(value: unknown, max: number): string {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\r\n/g, '\n').slice(0, max);
}

function textArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item).trim()).filter(Boolean);
}

function articleView(row: Record<string, unknown>) {
  return {
    publicArticleId: String(row.public_article_id),
    slug: String(row.slug),
    category: String(row.category),
    title: String(row.title),
    summary: String(row.summary),
    body: String(row.body),
    steps: textArray(row.steps),
    tags: textArray(row.tags),
    safetyLevel: String(row.safety_level),
    safetyNotice: String(row.safety_notice ?? ''),
    escalationText: String(row.escalation_text ?? ''),
    nexusReady: Boolean(row.nexus_ready),
    isFeatured: Boolean(row.is_featured),
    version: Number(row.version),
    publishedAt: row.published_at == null ? null : String(row.published_at),
    helpfulCount: Number(row.helpful_count ?? 0),
    notHelpfulCount: Number(row.not_helpful_count ?? 0),
  };
}

async function listArticles(req: Request, sql: DbClient): Promise<Response> {
  const url = new URL(req.url);
  const q = cleanText(url.searchParams.get('q'), 120);
  const category = cleanText(url.searchParams.get('category'), 40);
  if (category && !categories.has(category)) {
    return json({ error: 'invalid_knowledge_category' }, 400);
  }
  const like = `%${q}%`;
  const prefix = `${q}%`;

  const rows = await sql`
    SELECT
      article.public_article_id,
      version.slug, version.category, version.title, version.summary,
      version.body, version.steps, version.tags, version.safety_level,
      version.safety_notice, version.escalation_text, version.nexus_ready,
      version.is_featured, version.version, version.published_at,
      COALESCE((
        SELECT count(*) FILTER (WHERE feedback.helpful = true)
        FROM public.hdc_knowledge_feedback feedback
        WHERE feedback.article_id = article.id
          AND feedback.article_version = version.version
      ), 0)::integer AS helpful_count,
      COALESCE((
        SELECT count(*) FILTER (WHERE feedback.helpful = false)
        FROM public.hdc_knowledge_feedback feedback
        WHERE feedback.article_id = article.id
          AND feedback.article_version = version.version
      ), 0)::integer AS not_helpful_count
    FROM public.hdc_knowledge_articles article
    JOIN public.hdc_knowledge_article_versions version
      ON version.article_id = article.id
     AND version.version = article.published_version
    WHERE article.published_version IS NOT NULL
      AND article.status <> 'archived'
      AND version.published_at IS NOT NULL
      AND version.published_at <= now()
      AND (${category} = '' OR version.category = ${category})
      AND (
        ${q} = '' OR
        version.title ILIKE ${like} OR
        version.summary ILIKE ${like} OR
        version.body ILIKE ${like} OR
        array_to_string(version.tags, ' ') ILIKE ${like}
      )
    ORDER BY
      CASE
        WHEN ${q} <> '' AND version.title ILIKE ${prefix} THEN 0
        WHEN ${q} <> '' AND version.title ILIKE ${like} THEN 1
        ELSE 2
      END,
      version.is_featured DESC,
      version.published_at DESC,
      version.title ASC
    LIMIT 60
  `;

  const countRows = await sql`
    SELECT version.category, count(*)::integer AS article_count
    FROM public.hdc_knowledge_articles article
    JOIN public.hdc_knowledge_article_versions version
      ON version.article_id = article.id
     AND version.version = article.published_version
    WHERE article.published_version IS NOT NULL
      AND article.status <> 'archived'
      AND version.published_at IS NOT NULL
      AND version.published_at <= now()
    GROUP BY version.category
    ORDER BY version.category
  `;

  return json({
    query: q,
    category: category || null,
    articles: rows.map((row) => articleView(row)),
    categoryCounts: Object.fromEntries(
      countRows.map((row) => [String(row.category), Number(row.article_count)]),
    ),
  });
}

async function articleDetail(slug: string, sql: DbClient): Promise<Response> {
  const rows = await sql`
    SELECT
      article.id AS article_id,
      article.public_article_id,
      version.slug, version.category, version.title, version.summary,
      version.body, version.steps, version.tags, version.safety_level,
      version.safety_notice, version.escalation_text, version.nexus_ready,
      version.is_featured, version.version, version.published_at,
      COALESCE((
        SELECT count(*) FILTER (WHERE feedback.helpful = true)
        FROM public.hdc_knowledge_feedback feedback
        WHERE feedback.article_id = article.id
          AND feedback.article_version = version.version
      ), 0)::integer AS helpful_count,
      COALESCE((
        SELECT count(*) FILTER (WHERE feedback.helpful = false)
        FROM public.hdc_knowledge_feedback feedback
        WHERE feedback.article_id = article.id
          AND feedback.article_version = version.version
      ), 0)::integer AS not_helpful_count
    FROM public.hdc_knowledge_articles article
    JOIN public.hdc_knowledge_article_versions version
      ON version.article_id = article.id
     AND version.version = article.published_version
    WHERE article.published_version IS NOT NULL
      AND article.status <> 'archived'
      AND version.slug = ${slug}
      AND version.published_at IS NOT NULL
      AND version.published_at <= now()
    LIMIT 1
  `;
  if (rows.length === 0) return json({ error: 'knowledge_article_not_found' }, 404);

  const article = rows[0];
  const related = await sql`
    SELECT
      related_article.public_article_id,
      related_version.slug, related_version.category, related_version.title,
      related_version.summary, related_version.body, related_version.steps,
      related_version.tags, related_version.safety_level,
      related_version.safety_notice, related_version.escalation_text,
      related_version.nexus_ready, related_version.is_featured,
      related_version.version, related_version.published_at,
      0::integer AS helpful_count,
      0::integer AS not_helpful_count
    FROM public.hdc_knowledge_articles related_article
    JOIN public.hdc_knowledge_article_versions related_version
      ON related_version.article_id = related_article.id
     AND related_version.version = related_article.published_version
    WHERE related_article.published_version IS NOT NULL
      AND related_article.status <> 'archived'
      AND related_article.id <> ${String(article.article_id)}::uuid
      AND related_version.category = ${String(article.category)}
      AND related_version.published_at IS NOT NULL
      AND related_version.published_at <= now()
    ORDER BY related_version.is_featured DESC, related_version.published_at DESC
    LIMIT 3
  `;

  return json({
    article: articleView(article),
    related: related.map((row) => articleView(row)),
  });
}

async function nexusRetrieval(req: Request, sql: DbClient): Promise<Response> {
  const url = new URL(req.url);
  const q = cleanText(url.searchParams.get('q'), 120);
  if (q.length < 2) {
    return json({ error: 'knowledge_query_required' }, 400);
  }
  const like = `%${q}%`;
  const rows = await sql`
    SELECT
      article.public_article_id,
      version.slug, version.category, version.title, version.summary,
      version.body, version.steps, version.tags, version.safety_level,
      version.safety_notice, version.escalation_text, version.nexus_ready,
      version.is_featured, version.version, version.published_at,
      0::integer AS helpful_count,
      0::integer AS not_helpful_count
    FROM public.hdc_knowledge_articles article
    JOIN public.hdc_knowledge_article_versions version
      ON version.article_id = article.id
     AND version.version = article.published_version
    WHERE article.published_version IS NOT NULL
      AND article.status <> 'archived'
      AND version.nexus_ready = true
      AND version.published_at IS NOT NULL
      AND version.published_at <= now()
      AND (
        version.title ILIKE ${like} OR
        version.summary ILIKE ${like} OR
        version.body ILIKE ${like} OR
        array_to_string(version.tags, ' ') ILIKE ${like}
      )
    ORDER BY
      CASE WHEN version.title ILIKE ${like} THEN 0 ELSE 1 END,
      version.is_featured DESC,
      version.published_at DESC
    LIMIT 5
  `;
  return json({
    query: q,
    authority: 'hdc_published_knowledge',
    generationAllowed: false,
    retrievals: rows.map((row) => articleView(row)),
  });
}

async function submitFeedback(req: Request, sql: DbClient): Promise<Response> {
  if (operationMode() !== 'normal') {
    return json({ error: 'service_read_only' }, 503);
  }
  const authorization = await authorizeMemberRequest(req, sql);
  if (authorization instanceof Response) return authorization;
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);

  const publicArticleId = cleanText(body.publicArticleId, 40);
  const version = Number(body.version);
  const note = cleanText(body.note, 1000);
  if (!publicArticleId || !Number.isInteger(version) || version < 1 || typeof body.helpful !== 'boolean') {
    return json({ error: 'invalid_knowledge_feedback' }, 400);
  }
  const helpful: boolean = body.helpful;

  const articleRows = await sql`
    SELECT id, published_version
    FROM public.hdc_knowledge_articles
    WHERE public_article_id = ${publicArticleId}
      AND status <> 'archived'
      AND published_version = ${version}
    LIMIT 1
  `;
  if (articleRows.length === 0) {
    return json({
      error: 'knowledge_article_version_changed',
      message: 'This guide changed. Refresh it before sending feedback.',
    }, 409);
  }
  const articleId = String(articleRows[0].id);
  const feedbackId = `KBF-${randomBytes(5).toString('hex').toUpperCase()}`;

  await sql.begin(async (tx) => {
    await tx`
      INSERT INTO public.hdc_knowledge_feedback (
        public_feedback_id, article_id, article_version, user_id, helpful, note
      ) VALUES (
        ${feedbackId}, ${articleId}::uuid, ${version},
        ${authorization.userId}::uuid, ${helpful}, ${note}
      )
      ON CONFLICT (article_id, user_id, article_version)
      DO UPDATE SET
        helpful = EXCLUDED.helpful,
        note = EXCLUDED.note,
        updated_at = now()
    `;
    await tx`
      INSERT INTO public.hdc_security_audit (user_id, event_type, event_status, metadata)
      VALUES (
        ${authorization.userId},
        'knowledge.feedback',
        'success',
        ${tx.json({
          publicArticleId,
          version,
          helpful,
        })}
      )
    `;
  });

  const counts = await sql`
    SELECT
      count(*) FILTER (WHERE helpful = true)::integer AS helpful_count,
      count(*) FILTER (WHERE helpful = false)::integer AS not_helpful_count
    FROM public.hdc_knowledge_feedback
    WHERE article_id = ${articleId}::uuid
      AND article_version = ${version}
  `;
  return json({
    saved: true,
    helpfulCount: Number(counts[0]?.helpful_count ?? 0),
    notHelpfulCount: Number(counts[0]?.not_helpful_count ?? 0),
  });
}

async function handle(req: Request): Promise<Response> {
  if (!['GET', 'POST'].includes(req.method)) return methodNotAllowed();
  const sql = openDb();
  try {
    if (req.method === 'POST') return await submitFeedback(req, sql);
    const url = new URL(req.url);
    if (url.searchParams.get('mode') === 'nexus') return await nexusRetrieval(req, sql);
    const slug = cleanText(url.searchParams.get('slug'), 160);
    if (slug) return await articleDetail(slug, sql);
    return await listArticles(req, sql);
  } catch (error) {
    console.error(
      'Knowledge Base request failed',
      error instanceof Error ? error.message : 'unknown_error',
    );
    return json({ error: 'knowledge_base_unavailable' }, 500);
  } finally {
    await closeDb(sql);
  }
}

export default async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return corsPreflightResponse(req);
  return withCors(req, await handle(req));
};

export const config = {
  path: '/api/knowledge',
};
