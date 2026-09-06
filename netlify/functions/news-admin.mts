import { openDb, closeDb, type DbClient } from './_lib/db.mjs';
import { corsPreflightResponse, withCors } from './_lib/cors.mjs';
import { bearerToken, json, methodNotAllowed, readJson } from './_lib/http.mjs';
import { verifySessionToken } from './_lib/session.mjs';
import { operationMode } from './_lib/env.mjs';

const privilegedInternalRoles = new Set(['owner', 'super_admin', 'admin']);
const kinds = new Set(['announcement', 'feature', 'maintenance', 'recognition']);
const statuses = new Set(['draft', 'published', 'archived']);

async function authorize(
  req: Request,
  sql: DbClient,
): Promise<{ userId: string; internalRoles: string[] } | Response> {
  const token = bearerToken(req);
  if (!token) return json({ error: 'authentication_required' }, 401);
  const verified = await verifySessionToken(token);
  if (!verified) return json({ error: 'invalid_session' }, 401);

  const sessions = await sql`
    SELECT 1
    FROM public.hdc_auth_sessions session
    JOIN public.hdc_users member ON member.id = session.user_id
    WHERE session.user_id = ${verified.userId}
      AND session.token_jti = ${verified.jti}
      AND session.revoked_at IS NULL
      AND session.expires_at > now()
      AND member.status = 'active'
    LIMIT 1
  `;
  if (sessions.length === 0) return json({ error: 'invalid_session' }, 401);

  const roleRows = await sql`
    SELECT role
    FROM public.hdc_internal_role_assignments
    WHERE user_id = ${verified.userId}
      AND is_active = true
    ORDER BY role
  `;
  const internalRoles = roleRows.map((row) => String(row.role));
  if (!internalRoles.some((role) => privilegedInternalRoles.has(role))) {
    return json({ error: 'news_management_forbidden' }, 403);
  }
  return { userId: verified.userId, internalRoles };
}

function view(row: Record<string, unknown>) {
  return {
    id: String(row.id),
    kind: String(row.kind),
    title: String(row.title),
    summary: String(row.summary),
    body: String(row.body),
    status: String(row.status),
    isPinned: Boolean(row.is_pinned),
    recognitionSubject: row.recognition_subject == null
      ? null
      : String(row.recognition_subject),
    recognitionConsentConfirmed: Boolean(row.recognition_consent_confirmed),
    publishedAt: row.published_at == null ? null : String(row.published_at),
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
  };
}

function cleanText(value: unknown, max: number): string {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\r\n/g, '\n').slice(0, max);
}

function parsePayload(body: Record<string, unknown>) {
  const kind = cleanText(body.kind, 32);
  const title = cleanText(body.title, 160);
  const summary = cleanText(body.summary, 320);
  const content = cleanText(body.body, 12000);
  const status = cleanText(body.status, 24);
  const recognitionSubject = cleanText(body.recognitionSubject, 160);
  const recognitionConsentConfirmed = body.recognitionConsentConfirmed === true;
  const isPinned = body.isPinned === true;

  if (!kinds.has(kind) || !statuses.has(status)) {
    return { error: 'invalid_news_type_or_status' } as const;
  }
  if (title.length < 3 || summary.length < 3 || content.length < 3) {
    return { error: 'invalid_news_content' } as const;
  }
  if (
    kind === 'recognition' &&
    status === 'published' &&
    (!recognitionConsentConfirmed || recognitionSubject.length < 2)
  ) {
    return { error: 'recognition_consent_required' } as const;
  }

  return {
    kind,
    title,
    summary,
    content,
    status,
    recognitionSubject: recognitionSubject || null,
    recognitionConsentConfirmed,
    isPinned,
  } as const;
}

async function list(sql: DbClient): Promise<Response> {
  const rows = await sql`
    SELECT
      id, kind, title, summary, body, status, is_pinned,
      recognition_subject, recognition_consent_confirmed,
      published_at, created_at, updated_at
    FROM public.hdc_public_news_posts
    ORDER BY
      CASE status WHEN 'draft' THEN 0 WHEN 'published' THEN 1 ELSE 2 END,
      is_pinned DESC,
      updated_at DESC
    LIMIT 200
  `;
  return json({ posts: rows.map((row) => view(row)) });
}

async function create(
  req: Request,
  sql: DbClient,
  actorId: string,
): Promise<Response> {
  if (operationMode() !== 'normal') {
    return json({ error: 'service_read_only' }, 503);
  }
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const parsed = parsePayload(body);
  if ('error' in parsed) return json({ error: parsed.error }, 400);

  const rows = await sql.begin(async (tx) => {
    const inserted = await tx`
      INSERT INTO public.hdc_public_news_posts (
        kind, title, summary, body, status, is_pinned,
        recognition_subject, recognition_consent_confirmed,
        published_at, created_by, updated_by
      ) VALUES (
        ${parsed.kind}, ${parsed.title}, ${parsed.summary}, ${parsed.content},
        ${parsed.status}, ${parsed.isPinned}, ${parsed.recognitionSubject},
        ${parsed.recognitionConsentConfirmed},
        ${parsed.status === 'published' ? new Date() : null},
        ${actorId}, ${actorId}
      )
      RETURNING
        id, kind, title, summary, body, status, is_pinned,
        recognition_subject, recognition_consent_confirmed,
        published_at, created_at, updated_at
    `;
    await tx`
      INSERT INTO public.hdc_security_audit (
        user_id, event_type, event_status, metadata
      ) VALUES (
        ${actorId}, 'news.create', 'success',
        ${tx.json({ postId: String(inserted[0].id), status: parsed.status, kind: parsed.kind })}
      )
    `;
    return inserted;
  });
  return json({ post: view(rows[0]) }, 201);
}

async function update(
  req: Request,
  sql: DbClient,
  actorId: string,
): Promise<Response> {
  if (operationMode() !== 'normal') {
    return json({ error: 'service_read_only' }, 503);
  }
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const id = cleanText(body.id, 80);
  if (!id) return json({ error: 'news_post_required' }, 400);
  const parsed = parsePayload(body);
  if ('error' in parsed) return json({ error: parsed.error }, 400);

  const rows = await sql.begin(async (tx) => {
    const updated = await tx`
      UPDATE public.hdc_public_news_posts
      SET
        kind = ${parsed.kind},
        title = ${parsed.title},
        summary = ${parsed.summary},
        body = ${parsed.content},
        status = ${parsed.status},
        is_pinned = ${parsed.isPinned},
        recognition_subject = ${parsed.recognitionSubject},
        recognition_consent_confirmed = ${parsed.recognitionConsentConfirmed},
        published_at = CASE
          WHEN ${parsed.status} = 'published' THEN COALESCE(published_at, now())
          WHEN ${parsed.status} = 'draft' THEN NULL
          ELSE published_at
        END,
        updated_by = ${actorId},
        updated_at = now()
      WHERE id = ${id}
      RETURNING
        id, kind, title, summary, body, status, is_pinned,
        recognition_subject, recognition_consent_confirmed,
        published_at, created_at, updated_at
    `;
    if (updated.length === 0) return updated;
    await tx`
      INSERT INTO public.hdc_security_audit (
        user_id, event_type, event_status, metadata
      ) VALUES (
        ${actorId}, 'news.update', 'success',
        ${tx.json({ postId: id, status: parsed.status, kind: parsed.kind })}
      )
    `;
    return updated;
  });
  if (rows.length === 0) return json({ error: 'news_post_not_found' }, 404);
  return json({ post: view(rows[0]) });
}

async function remove(
  req: Request,
  sql: DbClient,
  actorId: string,
): Promise<Response> {
  if (operationMode() !== 'normal') {
    return json({ error: 'service_read_only' }, 503);
  }
  const id = (new URL(req.url).searchParams.get('id') ?? '').trim();
  if (!id) return json({ error: 'news_post_required' }, 400);

  const rows = await sql.begin(async (tx) => {
    const deleted = await tx`
      DELETE FROM public.hdc_public_news_posts
      WHERE id = ${id}
        AND status <> 'published'
      RETURNING id, title, status
    `;
    if (deleted.length === 0) return deleted;
    await tx`
      INSERT INTO public.hdc_security_audit (
        user_id, event_type, event_status, metadata
      ) VALUES (
        ${actorId}, 'news.delete', 'success',
        ${tx.json({ postId: id, title: String(deleted[0].title) })}
      )
    `;
    return deleted;
  });
  if (rows.length === 0) {
    return json({
      error: 'news_delete_not_allowed',
      message: 'Published posts must be archived before deletion.',
    }, 409);
  }
  return json({ deleted: true, id });
}

async function handle(req: Request): Promise<Response> {
  if (!['GET', 'POST', 'PUT', 'DELETE'].includes(req.method)) {
    return methodNotAllowed();
  }
  const sql = openDb();
  try {
    const authorization = await authorize(req, sql);
    if (authorization instanceof Response) return authorization;
    if (req.method === 'GET') return await list(sql);
    if (req.method === 'POST') return await create(req, sql, authorization.userId);
    if (req.method === 'PUT') return await update(req, sql, authorization.userId);
    return await remove(req, sql, authorization.userId);
  } catch (error) {
    console.error(
      'News admin failed',
      error instanceof Error ? error.message : 'unknown_error',
    );
    return json({ error: 'news_management_failed' }, 500);
  } finally {
    await closeDb(sql);
  }
}

export default async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return corsPreflightResponse(req);
  return withCors(req, await handle(req));
};

export const config = {
  path: '/api/internal/news',
};
