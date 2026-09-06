import type { DbClient } from './db.mjs';
import { bearerToken, json } from './http.mjs';
import { verifySessionToken } from './session.mjs';

export type AuthorizedInternalRequest = {
  userId: string;
  internalRoles: string[];
};

export async function authorizeInternalRequest(
  req: Request,
  sql: DbClient,
  allowedRoles: ReadonlySet<string>,
  forbiddenError: string,
): Promise<AuthorizedInternalRequest | Response> {
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
  if (!internalRoles.some((role) => allowedRoles.has(role))) {
    return json({ error: forbiddenError }, 403);
  }
  return { userId: verified.userId, internalRoles };
}
