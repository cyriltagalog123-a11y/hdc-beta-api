import type { Config, Context } from '@netlify/functions';
import { closeDb, openDb } from './_lib/db.mjs';
import { databaseUrl, sessionSecret } from './_lib/env.mjs';

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

export default async (req: Request, _context: Context): Promise<Response> => {
  if (req.method !== 'GET') return json({ error: 'method_not_allowed' }, 405);

  let databaseConfigured = false;
  let signingConfigured = false;
  let databaseReachable = false;
  let authSchemaReady = false;

  try {
    databaseConfigured = databaseUrl().length > 0;
  } catch (_) {
    databaseConfigured = false;
  }

  try {
    signingConfigured = sessionSecret().length >= 32;
  } catch (_) {
    signingConfigured = false;
  }

  if (databaseConfigured) {
    const sql = openDb();
    try {
      await sql`SELECT 1 AS ok`;
      databaseReachable = true;

      const rows = await sql`
        SELECT count(*)::int AS ready_tables
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name IN (
            'hdc_users',
            'hdc_user_roles',
            'hdc_auth_sessions',
            'hdc_security_audit'
          )
      `;
      authSchemaReady = Number(rows[0]?.ready_tables ?? 0) === 4;
    } catch (_) {
      databaseReachable = false;
      authSchemaReady = false;
    } finally {
      await closeDb(sql);
    }
  }

  const healthy =
      databaseConfigured && signingConfigured && databaseReachable && authSchemaReady;

  return json({
    service: 'hdc-beta-api',
    status: healthy ? 'ok' : 'degraded',
    checks: {
      databaseConfigured,
      signingConfigured,
      databaseReachable,
      authSchemaReady,
    },
  }, healthy ? 200 : 503);
};

export const config: Config = {
  path: '/api/auth-diagnostic',
};
