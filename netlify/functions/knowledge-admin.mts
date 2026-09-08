import { randomBytes } from 'node:crypto';

import { openDb, closeDb, type DbClient } from './_lib/db.mjs';
import { corsPreflightResponse, withCors } from './_lib/cors.mjs';
import { json, methodNotAllowed, readJson } from './_lib/http.mjs';
import { operationMode } from './_lib/env.mjs';
import { authorizeInternalRequest } from './_lib/internal-auth.mjs';

const writerRoles = new Set(['owner', 'super_admin', 'admin']);
const publisherRoles = new Set(['owner', 'super_admin']);
const categories = new Set([
  'pc_laptop',
  'phones_mobile',
  'pos_business_tech',
  'network_internet',
  'printers_peripherals',
  'security_accounts',
]);
const safetyLevels = new Set(['low', 'moderate', 'high']);
const statuses = new Set(['draft', 'review', 'published', 'archived']);

function cleanText(value: unknown, max: number): string {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\r\n/g, '\n').slice(0, max);
}

function cleanList(value: unknown, maxItems: number, maxItemLength: number): string[] {
  if (!Array.isArray(value)) return [];
  const result: string[] = [];
  for (const item of value) {
    const text = cleanText(item, maxItemLength);
    if (!text || result.includes(text)) continue;
    result.push(text);
    if (result.length >= maxItems) break;
  }
  return result;
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 120);
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function isUniqueViolation(error: unknown): boolean {
  return typeof error === 'object' && error !== null &&
    'code' in error && (error as { code?: unknown }).code === '23505';
}

function canPublish(roles: readonly string[]): boolean {
  return roles.some((role) => publisherRoles.has(role));
}

function articleView(row: Record<string, unknown>) {
  return {
    id: String(row.id),
    publicArticleId: String(row.public_article_id),
    slug: String(row.slug),
    category: String(row.category),
    title: String(row.title),
    summary: String(row.summary),
    body: String(row.body),
    steps: Array.isArray(row.steps) ? row.steps.map((item) => String(item)) : [],
    tags: Array.isArray(row.tags) ? row.tags.map((item) => String(item)) : [],
    safetyLevel: String(row.safety_level),
    safetyNotice: String(row.safety_notice ?? ''),
    escalationText: String(row.escalation_text ?? ''),
    nexusReady: Boolean(row.nexus_ready),
    isFeatured: Boolean(row.is_featured),
    status: String(row.status),
    version: Number(row.version),
    publishedVersion: row.published_version == null ? null : Number(row.published_version),
    everPublished: Boolean(row.ever_published),
    publicVisible:
      Boolean(row.ever_published) &&
      row.published_version != null &&
      String(row.status) !== 'archived',
    publishedAt: row.published_at == null ? null : String(row.published_at),
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
  };
}

function versionView(row: Record<string, unknown>) {
  return {
    version: Number(row.version),
    slug: String(row.slug),
    category: String(row.category),
    title: String(row.title),
    summary: String(row.summary),
    safetyLevel: String(row.safety_level),
    nexusReady: Boolean(row.nexus_ready),
    isFeatured: Boolean(row.is_featured),
    workflowStatus: String(row.workflow_status),
    changeNote: String(row.change_note ?? ''),
    createdAt: String(row.created_at),
    publishedAt: row.published_at == null ? null : String(row.published_at),
  };
}

function parsePayload(body: Record<string, unknown>) {
  const title = cleanText(body.title, 180);
  const requestedSlug = cleanText(body.slug, 140);
  const slug = slugify(requestedSlug || title);
  const category = cleanText(body.category, 40);
  const summary = cleanText(body.summary, 500);
  const content = cleanText(body.body, 20000);
  const steps = cleanList(body.steps, 20, 700);
  const tags = cleanList(body.tags, 16, 48).map((tag) => tag.toLowerCase());
  const safetyLevel = cleanText(body.safetyLevel, 24);
  const safetyNotice = cleanText(body.safetyNotice, 1200);
  const escalationText = cleanText(body.escalationText, 1600);
  const status = cleanText(body.status, 24);
  const changeNote = cleanText(body.changeNote, 500);
  const nexusReady = body.nexusReady !== false;
  const isFeatured = body.isFeatured === true;

  if (!categories.has(category) || !safetyLevels.has(safetyLevel) || !statuses.has(status)) {
    return { error: 'invalid_knowledge_classification' } as const;
  }
  if (
    title.length < 5 || slug.length < 3 || summary.length < 10 ||
    content.length < 20 || steps.length === 0
  ) {
    return { error: 'invalid_knowledge_content' } as const;
  }
  if (safetyLevel !== 'low' && safetyNotice.length < 10) {
    return { error: 'knowledge_safety_notice_required' } as const;
  }
  if (safetyLevel === 'high' && escalationText.length < 10) {
    return { error: 'knowledge_escalation_required' } as const;
  }

  return {
    title,
    slug,
    category,
    summary,
    content,
    steps,
    tags,
    safetyLevel,
    safetyNotice,
    escalationText,
    status,
    changeNote,
    nexusReady,
    isFeatured,
  } as const;
}

async function list(sql: DbClient, roles: readonly string[]): Promise<Response> {
  const rows = await sql`
    SELECT
      id, public_article_id, slug, category, title, summary, body, steps, tags,
      safety_level, safety_notice, escalation_text, nexus_ready, is_featured,
      status, version, published_version, ever_published, published_at,
      created_at, updated_at
    FROM public.hdc_knowledge_articles
    ORDER BY
      CASE status WHEN 'review' THEN 0 WHEN 'draft' THEN 1 WHEN 'published' THEN 2 ELSE 3 END,
      is_featured DESC,
      updated_at DESC
    LIMIT 300
  `;
  return json({
    canPublish: canPublish(roles),
    articles: rows.map((row) => articleView(row)),
  });
}

async function history(req: Request, sql: DbClient, roles: readonly string[]): Promise<Response> {
  const id = cleanText(new URL(req.url).searchParams.get('id'), 80);
  if (!isUuid(id)) return json({ error: 'knowledge_article_required' }, 400);
  const rows = await sql`
    SELECT
      version, slug, category, title, summary, safety_level,
      nexus_ready, is_featured, workflow_status, change_note,
      created_at, published_at
    FROM public.hdc_knowledge_article_versions
    WHERE article_id = ${id}::uuid
    ORDER BY version DESC
    LIMIT 100
  `;
  return json({ canPublish: canPublish(roles), versions: rows.map((row) => versionView(row)) });
}

async function create(
  req: Request,
  sql: DbClient,
  actorId: string,
  roles: readonly string[],
): Promise<Response> {
  if (operationMode() !== 'normal') return json({ error: 'service_read_only' }, 503);
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const parsed = parsePayload(body);
  if ('error' in parsed) return json({ error: parsed.error }, 400);
  if (parsed.status === 'archived') return json({ error: 'invalid_new_knowledge_status' }, 400);
  if (parsed.status === 'published' && !canPublish(roles)) {
    return json({ error: 'knowledge_publish_forbidden' }, 403);
  }

  const slugConflict = await sql`
    SELECT 1 FROM public.hdc_knowledge_articles WHERE slug = ${parsed.slug} LIMIT 1
  `;
  if (slugConflict.length > 0) return json({ error: 'knowledge_slug_conflict' }, 409);

  const publicArticleId = `KB-${randomBytes(5).toString('hex').toUpperCase()}`;
  const publishedAt = parsed.status === 'published' ? new Date() : null;
  let articleId: string;
  try {
    articleId = await sql.begin(async (tx) => {
      const inserted = await tx`
        INSERT INTO public.hdc_knowledge_articles (
          public_article_id, slug, category, title, summary, body, steps, tags,
          safety_level, safety_notice, escalation_text, nexus_ready, is_featured,
          status, version, published_version, ever_published, published_at,
          created_by, updated_by
        ) VALUES (
          ${publicArticleId}, ${parsed.slug}, ${parsed.category}, ${parsed.title},
          ${parsed.summary}, ${parsed.content}, ${tx.json(parsed.steps)}, ${parsed.tags},
          ${parsed.safetyLevel}, ${parsed.safetyNotice}, ${parsed.escalationText},
          ${parsed.nexusReady}, ${parsed.isFeatured}, ${parsed.status}, 1, NULL,
          ${parsed.status === 'published'}, ${publishedAt}, ${actorId}, ${actorId}
        )
        RETURNING id
      `;
      const insertedArticleId = String(inserted[0].id);
      await tx`
        INSERT INTO public.hdc_knowledge_article_versions (
          article_id, version, slug, category, title, summary, body, steps, tags,
          safety_level, safety_notice, escalation_text, nexus_ready, is_featured,
          workflow_status, change_note, created_by, published_at
        ) VALUES (
          ${insertedArticleId}::uuid, 1, ${parsed.slug}, ${parsed.category}, ${parsed.title},
          ${parsed.summary}, ${parsed.content}, ${tx.json(parsed.steps)}, ${parsed.tags},
          ${parsed.safetyLevel}, ${parsed.safetyNotice}, ${parsed.escalationText},
          ${parsed.nexusReady}, ${parsed.isFeatured}, ${parsed.status},
          ${parsed.changeNote || 'Initial article version'}, ${actorId}, ${publishedAt}
        )
      `;
      if (parsed.status === 'published') {
        await tx`
          UPDATE public.hdc_knowledge_articles
          SET published_version = 1
          WHERE id = ${insertedArticleId}::uuid
        `;
      }
      await tx`
        INSERT INTO public.hdc_security_audit (user_id, event_type, event_status, metadata)
        VALUES (
          ${actorId}, 'knowledge.create', 'success',
          ${tx.json({ publicArticleId, status: parsed.status, category: parsed.category })}
        )
      `;
      return insertedArticleId;
    });
  } catch (error) {
    if (isUniqueViolation(error)) {
      return json({ error: 'knowledge_slug_conflict' }, 409);
    }
    throw error;
  }

  const result = await sql`
    SELECT
      id, public_article_id, slug, category, title, summary, body, steps, tags,
      safety_level, safety_notice, escalation_text, nexus_ready, is_featured,
      status, version, published_version, ever_published, published_at,
      created_at, updated_at
    FROM public.hdc_knowledge_articles
    WHERE id = ${articleId}::uuid
  `;
  return json({ article: articleView(result[0]), canPublish: canPublish(roles) }, 201);
}

async function update(
  req: Request,
  sql: DbClient,
  actorId: string,
  roles: readonly string[],
): Promise<Response> {
  if (operationMode() !== 'normal') return json({ error: 'service_read_only' }, 503);
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const id = cleanText(body.id, 80);
  if (!isUuid(id)) return json({ error: 'knowledge_article_required' }, 400);
  const expectedVersion = body.expectedVersion;
  if (
    typeof expectedVersion !== 'number' ||
    !Number.isInteger(expectedVersion) ||
    expectedVersion < 1
  ) {
    return json({ error: 'invalid_knowledge_version' }, 400);
  }
  const parsed = parsePayload(body);
  if ('error' in parsed) return json({ error: parsed.error }, 400);
  if ((parsed.status === 'published' || parsed.status === 'archived') && !canPublish(roles)) {
    return json({ error: 'knowledge_publish_forbidden' }, 403);
  }

  type UpdateOutcome =
    | { kind: 'not_found' }
    | { kind: 'version_conflict'; currentVersion: number }
    | { kind: 'forbidden' }
    | { kind: 'slug_locked' }
    | { kind: 'slug_conflict' }
    | { kind: 'updated'; article: Record<string, unknown> };

  let outcome: UpdateOutcome;
  try {
    outcome = await sql.begin(async (tx): Promise<UpdateOutcome> => {
      const currentRows = await tx`
        SELECT
          id, public_article_id, slug, status, version,
          published_version, ever_published
        FROM public.hdc_knowledge_articles
        WHERE id = ${id}::uuid
        FOR UPDATE
      `;
      if (currentRows.length === 0) return { kind: 'not_found' };

      const current = currentRows[0];
      const currentVersion = Number(current.version);
      if (currentVersion !== expectedVersion) {
        return { kind: 'version_conflict', currentVersion };
      }
      if (String(current.status) === 'archived' && !canPublish(roles)) {
        return { kind: 'forbidden' };
      }
      if (Boolean(current.ever_published) && parsed.slug !== String(current.slug)) {
        return { kind: 'slug_locked' };
      }

      const slugConflict = await tx`
        SELECT 1
        FROM public.hdc_knowledge_articles
        WHERE slug = ${parsed.slug} AND id <> ${id}::uuid
        LIMIT 1
      `;
      if (slugConflict.length > 0) return { kind: 'slug_conflict' };

      const nextVersion = currentVersion + 1;
      const publishing = parsed.status === 'published';
      const publishedAt = publishing ? new Date() : null;
      await tx`
        INSERT INTO public.hdc_knowledge_article_versions (
          article_id, version, slug, category, title, summary, body, steps, tags,
          safety_level, safety_notice, escalation_text, nexus_ready, is_featured,
          workflow_status, change_note, created_by, published_at
        ) VALUES (
          ${id}::uuid, ${nextVersion}, ${parsed.slug}, ${parsed.category}, ${parsed.title},
          ${parsed.summary}, ${parsed.content}, ${tx.json(parsed.steps)}, ${parsed.tags},
          ${parsed.safetyLevel}, ${parsed.safetyNotice}, ${parsed.escalationText},
          ${parsed.nexusReady}, ${parsed.isFeatured}, ${parsed.status},
          ${parsed.changeNote || `Version ${nextVersion}`}, ${actorId}, ${publishedAt}
        )
      `;
      const updatedRows = await tx`
        UPDATE public.hdc_knowledge_articles
        SET
          slug = ${parsed.slug},
          category = ${parsed.category},
          title = ${parsed.title},
          summary = ${parsed.summary},
          body = ${parsed.content},
          steps = ${tx.json(parsed.steps)},
          tags = ${parsed.tags},
          safety_level = ${parsed.safetyLevel},
          safety_notice = ${parsed.safetyNotice},
          escalation_text = ${parsed.escalationText},
          nexus_ready = ${parsed.nexusReady},
          is_featured = ${parsed.isFeatured},
          status = ${parsed.status},
          version = ${nextVersion},
          published_version = CASE
            WHEN ${publishing} THEN ${nextVersion}
            ELSE published_version
          END,
          ever_published = ever_published OR ${publishing},
          published_at = CASE
            WHEN ${publishing} THEN ${publishedAt}
            ELSE published_at
          END,
          updated_by = ${actorId},
          updated_at = now()
        WHERE id = ${id}::uuid
        RETURNING
          id, public_article_id, slug, category, title, summary, body, steps, tags,
          safety_level, safety_notice, escalation_text, nexus_ready, is_featured,
          status, version, published_version, ever_published, published_at,
          created_at, updated_at
      `;
      await tx`
        INSERT INTO public.hdc_security_audit (user_id, event_type, event_status, metadata)
        VALUES (
          ${actorId}, 'knowledge.update', 'success',
          ${tx.json({
            publicArticleId: String(current.public_article_id),
            version: nextVersion,
            status: parsed.status,
            publishedVersion: publishing ? nextVersion : current.published_version,
          })}
        )
      `;
      return {
        kind: 'updated',
        article: updatedRows[0] as Record<string, unknown>,
      };
    });
  } catch (error) {
    if (isUniqueViolation(error)) {
      return json({ error: 'knowledge_slug_conflict' }, 409);
    }
    throw error;
  }

  if (outcome.kind === 'not_found') {
    return json({ error: 'knowledge_article_not_found' }, 404);
  }
  if (outcome.kind === 'version_conflict') {
    return json({
      error: 'knowledge_version_conflict',
      message: 'This guide changed after you opened it. Refresh before saving.',
      currentVersion: outcome.currentVersion,
    }, 409);
  }
  if (outcome.kind === 'forbidden') {
    return json({ error: 'knowledge_publish_forbidden' }, 403);
  }
  if (outcome.kind === 'slug_locked') {
    return json({
      error: 'knowledge_slug_locked',
      message: 'Published HDC guide links are permanent.',
    }, 409);
  }
  if (outcome.kind === 'slug_conflict') {
    return json({ error: 'knowledge_slug_conflict' }, 409);
  }
  return json({
    article: articleView(outcome.article),
    canPublish: canPublish(roles),
  });
}

async function remove(
  req: Request,
  sql: DbClient,
  actorId: string,
): Promise<Response> {
  if (operationMode() !== 'normal') return json({ error: 'service_read_only' }, 503);
  const id = cleanText(new URL(req.url).searchParams.get('id'), 80);
  if (!isUuid(id)) return json({ error: 'knowledge_article_required' }, 400);
  const deleted = await sql.begin(async (tx) => {
    const rows = await tx`
      DELETE FROM public.hdc_knowledge_articles
      WHERE id = ${id}::uuid
        AND ever_published = false
        AND published_version IS NULL
        AND status IN ('draft', 'review')
      RETURNING public_article_id, title
    `;
    if (rows.length === 0) return rows;
    await tx`
      INSERT INTO public.hdc_security_audit (user_id, event_type, event_status, metadata)
      VALUES (
        ${actorId}, 'knowledge.delete', 'success',
        ${tx.json({
          publicArticleId: String(rows[0].public_article_id),
          title: String(rows[0].title),
        })}
      )
    `;
    return rows;
  });
  if (deleted.length === 0) {
    return json({
      error: 'knowledge_delete_not_allowed',
      message: 'Only never-published drafts or review copies can be deleted. Published knowledge must be archived and retained.',
    }, 409);
  }
  return json({ deleted: true, publicArticleId: String(deleted[0].public_article_id) });
}

async function handle(req: Request): Promise<Response> {
  if (!['GET', 'POST', 'PUT', 'DELETE'].includes(req.method)) return methodNotAllowed();
  const sql = openDb();
  try {
    const authorization = await authorizeInternalRequest(
      req,
      sql,
      writerRoles,
      'knowledge_management_forbidden',
    );
    if (authorization instanceof Response) return authorization;

    if (req.method === 'GET') {
      const view = new URL(req.url).searchParams.get('view');
      if (view === 'history') return await history(req, sql, authorization.internalRoles);
      return await list(sql, authorization.internalRoles);
    }
    if (req.method === 'POST') {
      return await create(req, sql, authorization.userId, authorization.internalRoles);
    }
    if (req.method === 'PUT') {
      return await update(req, sql, authorization.userId, authorization.internalRoles);
    }
    return await remove(req, sql, authorization.userId);
  } catch (error) {
    console.error(
      'Knowledge management failed',
      error instanceof Error ? error.message : 'unknown_error',
    );
    return json({ error: 'knowledge_management_failed' }, 500);
  } finally {
    await closeDb(sql);
  }
}

export default async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return corsPreflightResponse(req);
  return withCors(req, await handle(req));
};

export const config = {
  path: '/api/internal/knowledge',
};
