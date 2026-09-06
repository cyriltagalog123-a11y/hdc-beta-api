import { openDb, closeDb, type DbClient } from './_lib/db.mjs';
import { corsPreflightResponse, withCors } from './_lib/cors.mjs';
import { json, methodNotAllowed, readJson } from './_lib/http.mjs';
import { operationMode } from './_lib/env.mjs';
import { authorizeInternalRequest } from './_lib/internal-auth.mjs';

const privilegedRoles = new Set(['owner', 'super_admin', 'admin']);
const statuses = new Set(['submitted', 'reviewing', 'planned', 'declined', 'implemented']);

function cleanText(value: unknown, max: number): string {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\r\n/g, '\n').slice(0, max);
}

async function authorize(req: Request, sql: DbClient) {
  return await authorizeInternalRequest(req, sql, privilegedRoles, 'suggestion_management_forbidden');
}

function view(row: Record<string, unknown>) {
  return {
    id: String(row.id),
    publicSuggestionId: String(row.public_suggestion_id),
    memberId: String(row.member_id),
    category: String(row.category),
    title: String(row.title),
    body: String(row.body),
    status: String(row.status),
    staffResponse: String(row.staff_response ?? ''),
    publicAttributionConsent: Boolean(row.public_attribution_consent),
    reviewedAt: row.reviewed_at == null ? null : String(row.reviewed_at),
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
  };
}

async function list(sql: DbClient) {
  const rows = await sql`
    SELECT id, public_suggestion_id, member_id, category, title, body, status,
           staff_response, public_attribution_consent, reviewed_at, created_at, updated_at
    FROM public.hdc_suggestions
    ORDER BY CASE status
      WHEN 'submitted' THEN 0 WHEN 'reviewing' THEN 1 WHEN 'planned' THEN 2
      WHEN 'implemented' THEN 3 ELSE 4 END,
      updated_at DESC
    LIMIT 300
  `;
  return json({ suggestions: rows.map((row) => view(row)) });
}

async function update(req: Request, sql: DbClient, actorId: string) {
  if (operationMode() !== 'normal') return json({ error: 'service_read_only' }, 503);
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const id = cleanText(body.id, 80);
  const status = cleanText(body.status, 24).toLowerCase();
  const staffResponse = cleanText(body.staffResponse, 3000);
  if (!id || !statuses.has(status)) return json({ error: 'invalid_suggestion_update' }, 400);

  const result = await sql.begin(async (tx) => {
    const rows = await tx`
      UPDATE public.hdc_suggestions
      SET status = ${status}, staff_response = ${staffResponse},
          reviewed_by = ${actorId}::uuid, reviewed_at = now()
      WHERE id = ${id}::uuid
      RETURNING id, public_suggestion_id, member_id, category, title, body, status,
                staff_response, public_attribution_consent, reviewed_at, created_at, updated_at
    `;
    if (rows.length === 0) return null;
    if (status === 'implemented') {
      await tx`SELECT public.hdc_sync_member_badges(${String(rows[0].member_id)}::uuid)`;
    }
    await tx`
      INSERT INTO public.hdc_security_audit(user_id, event_type, event_status, metadata)
      VALUES (${actorId}::uuid, 'suggestion.update', 'success',
              ${tx.json({ suggestionId: id, publicSuggestionId: String(rows[0].public_suggestion_id), status })})
    `;
    return rows[0];
  });
  if (!result) return json({ error: 'suggestion_not_found' }, 404);
  return json({ suggestion: view(result) });
}

async function handle(req: Request): Promise<Response> {
  if (!['GET', 'PUT'].includes(req.method)) return methodNotAllowed();
  const sql = openDb();
  try {
    const authorization = await authorize(req, sql);
    if (authorization instanceof Response) return authorization;
    if (req.method === 'GET') return await list(sql);
    return await update(req, sql, authorization.userId);
  } catch (error) {
    console.error('Suggestion admin failed', error instanceof Error ? error.message : 'unknown_error');
    return json({ error: 'suggestion_management_failed' }, 500);
  } finally {
    await closeDb(sql);
  }
}

export default async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return corsPreflightResponse(req);
  return withCors(req, await handle(req));
};

export const config = { path: '/api/internal/community' };
