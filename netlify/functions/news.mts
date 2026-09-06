import { openDb, closeDb } from './_lib/db.mjs';
import { corsPreflightResponse, withCors } from './_lib/cors.mjs';
import { json, methodNotAllowed } from './_lib/http.mjs';

function view(row: Record<string, unknown>) {
  return {
    id: String(row.id),
    kind: String(row.kind),
    title: String(row.title),
    summary: String(row.summary),
    body: String(row.body),
    isPinned: Boolean(row.is_pinned),
    recognitionSubject: row.recognition_subject == null
      ? null
      : String(row.recognition_subject),
    publishedAt: row.published_at == null ? null : String(row.published_at),
    updatedAt: String(row.updated_at),
  };
}

async function handle(req: Request): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  const sql = openDb();
  try {
    const rows = await sql`
      SELECT
        id, kind, title, summary, body, is_pinned,
        recognition_subject, published_at, updated_at
      FROM public.hdc_public_news_posts
      WHERE status = 'published'
        AND published_at IS NOT NULL
        AND published_at <= now()
      ORDER BY is_pinned DESC, published_at DESC, created_at DESC
      LIMIT 100
    `;
    return json({ posts: rows.map((row) => view(row)) });
  } catch (error) {
    console.error(
      'Public news feed failed',
      error instanceof Error ? error.message : 'unknown_error',
    );
    return json({ error: 'news_feed_unavailable' }, 500);
  } finally {
    await closeDb(sql);
  }
}

export default async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return corsPreflightResponse(req);
  return withCors(req, await handle(req));
};

export const config = {
  path: '/api/news',
};
