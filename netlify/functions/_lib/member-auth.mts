import type { DbClient } from './db.mjs';
import { bearerToken, json } from './http.mjs';
import { verifySessionToken } from './session.mjs';

export type AuthorizedMemberRequest = {
  userId: string;
};

export async function authorizeMemberRequest(
  req: Request,
  sql: DbClient,
): Promise<AuthorizedMemberRequest | Response> {
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
  return { userId: verified.userId };
}
