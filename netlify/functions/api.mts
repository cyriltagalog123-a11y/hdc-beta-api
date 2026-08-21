import type { Config, Context } from '@netlify/functions';
import bcrypt from 'bcryptjs';
import { createHmac, randomUUID } from 'node:crypto';
import type { DbClient } from './_lib/db.mjs';
import { closeDb, openDb } from './_lib/db.mjs';
import { bearerToken, json, methodNotAllowed, readJson } from './_lib/http.mjs';
import { sessionSecret } from './_lib/env.mjs';
import { signSessionToken, verifySessionToken } from './_lib/session.mjs';
import { normalizeDisplayName, normalizeEmail, normalizePassword } from './_lib/validation.mjs';

const SESSION_DAYS = 7;
const LOGIN_FAILURE_LIMIT = 5;
const LOGIN_FAILURE_WINDOW_MINUTES = 15;

type UserView = {
  id: string;
  email: string;
  displayName: string;
  status: string;
  emailVerified: boolean;
  roles: string[];
  createdAt: string;
  updatedAt: string;
};

function identityFingerprint(email: string): string {
  return createHmac('sha256', sessionSecret()).update(email).digest('hex');
}

async function audit(
  sql: DbClient,
  userId: string | null,
  eventType: string,
  eventStatus: string,
  metadata: Record<string, unknown> = {},
): Promise<void> {
  try {
    await sql`
      INSERT INTO public.hdc_security_audit (user_id, event_type, event_status, metadata)
      VALUES (${userId}, ${eventType}, ${eventStatus}, ${sql.json(metadata)})
    `;
  } catch (error) {
    console.error('HDC security audit write failed', error instanceof Error ? error.message : 'unknown_error');
  }
}

async function getUserView(sql: DbClient, userId: string): Promise<UserView | null> {
  const users = await sql`
    SELECT id, email::text AS email, display_name, status, email_verified,
           created_at, updated_at
    FROM public.hdc_users
    WHERE id = ${userId}
    LIMIT 1
  `;
  if (users.length === 0) return null;

  const roles = await sql`
    SELECT role
    FROM public.hdc_user_roles
    WHERE user_id = ${userId} AND is_active = true
    ORDER BY role
  `;

  const user = users[0];
  return {
    id: String(user.id),
    email: String(user.email),
    displayName: String(user.display_name),
    status: String(user.status),
    emailVerified: Boolean(user.email_verified),
    roles: roles.map((row) => String(row.role)),
    createdAt: new Date(String(user.created_at)).toISOString(),
    updatedAt: new Date(String(user.updated_at)).toISOString(),
  };
}

async function activeSession(req: Request, sql: DbClient): Promise<{ user: UserView; jti: string } | null> {
  const token = bearerToken(req);
  if (!token) return null;

  const verified = await verifySessionToken(token);
  if (!verified) return null;

  const sessions = await sql`
    SELECT id
    FROM public.hdc_auth_sessions
    WHERE user_id = ${verified.userId}
      AND token_jti = ${verified.jti}
      AND revoked_at IS NULL
      AND expires_at > now()
    LIMIT 1
  `;
  if (sessions.length === 0) return null;

  const user = await getUserView(sql, verified.userId);
  if (!user || user.status !== 'active') return null;

  await sql`
    UPDATE public.hdc_auth_sessions
    SET last_seen_at = now()
    WHERE user_id = ${verified.userId} AND token_jti = ${verified.jti}
  `;

  return { user, jti: verified.jti };
}

async function handleRegister(req: Request, sql: DbClient): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);

  const email = normalizeEmail(body.email);
  const displayName = normalizeDisplayName(body.displayName);
  const password = normalizePassword(body.password);
  if (!email || !displayName || !password) {
    return json({
      error: 'invalid_registration',
      message: 'Provide a valid email, display name, and password of 12-128 characters.',
    }, 400);
  }

  const passwordHash = await bcrypt.hash(password, 12);

  try {
    const created = await sql.begin(async (tx) => {
      const rows = await tx`
        INSERT INTO public.hdc_users (email, password_hash, display_name)
        VALUES (${email}, ${passwordHash}, ${displayName})
        RETURNING id
      `;
      const userId = String(rows[0].id);
      await tx`
        INSERT INTO public.hdc_user_roles (user_id, role, is_active)
        VALUES (${userId}, 'customer', true)
      `;
      return userId;
    });

    await audit(sql, created, 'auth.register', 'success', { source: 'public_registration' });
    const user = await getUserView(sql, created);
    return json({ user }, 201);
  } catch (error) {
    const code = typeof error === 'object' && error !== null && 'code' in error
      ? String((error as { code?: unknown }).code ?? '')
      : '';
    if (code === '23505') {
      await audit(sql, null, 'auth.register', 'failed', { reason: 'email_already_registered' });
      return json({ error: 'email_already_registered' }, 409);
    }
    console.error('Registration failed', error instanceof Error ? error.message : 'unknown_error');
    return json({ error: 'registration_failed' }, 500);
  }
}

async function recentLoginFailures(sql: DbClient, fingerprint: string): Promise<number> {
  const rows = await sql`
    SELECT count(*)::int AS failures
    FROM public.hdc_security_audit
    WHERE event_type = 'auth.login'
      AND event_status = 'failed'
      AND metadata->>'identity_fingerprint' = ${fingerprint}
      AND created_at > now() - (${LOGIN_FAILURE_WINDOW_MINUTES} * interval '1 minute')
  `;
  return Number(rows[0]?.failures ?? 0);
}

async function handleLogin(req: Request, sql: DbClient): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);

  const email = normalizeEmail(body.email);
  const password = typeof body.password === 'string' ? body.password : null;
  if (!email || !password || password.length > 128) {
    return json({ error: 'invalid_credentials' }, 401);
  }

  const fingerprint = identityFingerprint(email);
  if (await recentLoginFailures(sql, fingerprint) >= LOGIN_FAILURE_LIMIT) {
    await audit(sql, null, 'auth.login', 'blocked', { reason: 'rate_limit', identity_fingerprint: fingerprint });
    return json({ error: 'too_many_attempts', message: 'Try again later.' }, 429);
  }

  const rows = await sql`
    SELECT id, password_hash, status
    FROM public.hdc_users
    WHERE email = ${email}
    LIMIT 1
  `;

  const row = rows[0];
  const valid = row ? await bcrypt.compare(password, String(row.password_hash)) : false;
  if (!row || !valid || String(row.status) !== 'active') {
    const userId = row ? String(row.id) : null;
    await audit(sql, userId, 'auth.login', 'failed', { reason: 'invalid_credentials', identity_fingerprint: fingerprint });
    return json({ error: 'invalid_credentials' }, 401);
  }

  const userId = String(row.id);
  const jti = randomUUID();
  const expiresAt = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
  const userAgent = (req.headers.get('user-agent') ?? '').slice(0, 500) || null;

  await sql`
    INSERT INTO public.hdc_auth_sessions (user_id, token_jti, expires_at, last_seen_at, user_agent)
    VALUES (${userId}, ${jti}, ${expiresAt}, now(), ${userAgent})
  `;

  const token = await signSessionToken(userId, jti, expiresAt);
  const user = await getUserView(sql, userId);
  await audit(sql, userId, 'auth.login', 'success', { session_jti: jti });

  return json({ token, expiresAt: expiresAt.toISOString(), user });
}

async function handleSession(req: Request, sql: DbClient): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  const session = await activeSession(req, sql);
  if (!session) return json({ error: 'unauthorized' }, 401);
  return json({ user: session.user });
}

async function handleLogout(req: Request, sql: DbClient): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const token = bearerToken(req);
  const verified = token ? await verifySessionToken(token) : null;
  if (!verified) return json({ error: 'unauthorized' }, 401);

  const result = await sql`
    UPDATE public.hdc_auth_sessions
    SET revoked_at = now()
    WHERE user_id = ${verified.userId}
      AND token_jti = ${verified.jti}
      AND revoked_at IS NULL
    RETURNING id
  `;
  if (result.length === 0) return json({ error: 'unauthorized' }, 401);

  await audit(sql, verified.userId, 'auth.logout', 'success', { session_jti: verified.jti });
  return json({ success: true });
}

export default async (req: Request, _context: Context): Promise<Response> => {
  const path = new URL(req.url).pathname;
  if (path === '/api/health') {
    if (req.method !== 'GET') return methodNotAllowed();
    return json({ service: 'hdc-beta-api', status: 'ok' });
  }

  const sql = openDb();
  try {
    if (path === '/api/auth/register') return await handleRegister(req, sql);
    if (path === '/api/auth/login') return await handleLogin(req, sql);
    if (path === '/api/auth/session') return await handleSession(req, sql);
    if (path === '/api/auth/logout') return await handleLogout(req, sql);
    return json({ error: 'not_found' }, 404);
  } catch (error) {
    console.error('Unhandled HDC API error', error instanceof Error ? error.message : 'unknown_error');
    return json({ error: 'internal_error' }, 500);
  } finally {
    await closeDb(sql);
  }
};

export const config: Config = {
  path: [
    '/api/health',
    '/api/auth/register',
    '/api/auth/login',
    '/api/auth/session',
    '/api/auth/logout',
  ],
};