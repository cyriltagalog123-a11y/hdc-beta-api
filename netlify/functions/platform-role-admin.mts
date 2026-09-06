import { openDb, closeDb, type DbClient } from './_lib/db.mjs';
import { corsPreflightResponse, withCors } from './_lib/cors.mjs';
import { json, methodNotAllowed, readJson } from './_lib/http.mjs';
import { operationMode } from './_lib/env.mjs';
import { authorizeInternalRequest } from './_lib/internal-auth.mjs';

const MANAGEABLE_PLATFORM_ROLES = Object.freeze([
  'technician',
  'seller',
  'business',
  'supplier',
  'store',
] as const);
type ManageablePlatformRole = typeof MANAGEABLE_PLATFORM_ROLES[number];
const manageableRoleSet = new Set<string>(MANAGEABLE_PLATFORM_ROLES);
const privilegedInternalRoles = new Set(['owner', 'super_admin', 'admin']);

async function authorize(req: Request, sql: DbClient) {
  return await authorizeInternalRequest(
    req,
    sql,
    privilegedInternalRoles,
    'platform_role_management_forbidden',
  );
}

function memberView(row: Record<string, unknown>) {
  const rawRoles = Array.isArray(row.platform_roles) ? row.platform_roles : [];
  return {
    id: String(row.id),
    publicMemberId: String(row.public_member_id),
    displayName: String(row.display_name),
    email: String(row.email),
    status: String(row.status),
    platformRoles: rawRoles.map(String),
  };
}

async function listMembers(req: Request, sql: DbClient): Promise<Response> {
  const url = new URL(req.url);
  const query = (url.searchParams.get('q') ?? '').trim();
  const pattern = `%${query}%`;
  const rows = await sql`
    SELECT
      member.id,
      member.public_member_id,
      member.display_name,
      member.email::text AS email,
      member.status,
      COALESCE(
        json_agg(assignment.role ORDER BY assignment.role)
          FILTER (WHERE assignment.role IS NOT NULL),
        '[]'::json
      ) AS platform_roles
    FROM public.hdc_users member
    LEFT JOIN public.hdc_user_roles assignment
      ON assignment.user_id = member.id
      AND assignment.is_active = true
      AND assignment.role::text IN (
        'customer', 'technician', 'seller', 'business', 'supplier', 'store'
      )
    WHERE (
      ${query} = '' OR
      member.display_name ILIKE ${pattern} OR
      member.email::text ILIKE ${pattern} OR
      member.public_member_id::text ILIKE ${pattern}
    )
    GROUP BY member.id
    ORDER BY member.display_name, member.created_at DESC
    LIMIT 50
  `;
  return json({ members: rows.map((row) => memberView(row)) });
}

async function mutateRole(
  req: Request,
  sql: DbClient,
  actorId: string,
): Promise<Response> {
  if (operationMode() !== 'normal') {
    return json({ error: 'service_read_only' }, 503);
  }
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);

  const targetUserId = typeof body.targetUserId === 'string'
    ? body.targetUserId.trim()
    : '';
  const role = typeof body.role === 'string' ? body.role.trim() : '';
  const action = typeof body.action === 'string' ? body.action.trim() : '';
  const reason = typeof body.reason === 'string'
    ? body.reason.trim().replace(/\s+/g, ' ')
    : '';

  if (!targetUserId || !manageableRoleSet.has(role)) {
    return json({
      error: 'invalid_platform_role_change',
      message: 'Choose a supported non-customer platform role and target member.',
    }, 400);
  }
  if (action !== 'assign' && action !== 'revoke') {
    return json({ error: 'invalid_platform_role_action' }, 400);
  }
  if (reason.length < 3 || reason.length > 500) {
    return json({
      error: 'platform_role_reason_required',
      message: 'Enter a short audit reason between 3 and 500 characters.',
    }, 400);
  }

  const targetRows = await sql`
    SELECT id, display_name, email::text AS email
    FROM public.hdc_users
    WHERE id = ${targetUserId} AND status = 'active'
    LIMIT 1
  `;
  if (targetRows.length === 0) {
    return json({ error: 'target_member_not_found' }, 404);
  }

  const typedRole = role as ManageablePlatformRole;
  if (action === 'assign') {
    await sql`
      INSERT INTO public.hdc_user_roles (
        user_id, role, is_active, granted_at, granted_by, revoked_at
      ) VALUES (
        ${targetUserId}, ${typedRole}, true, now(), ${actorId}, NULL
      )
      ON CONFLICT (user_id, role)
      DO UPDATE SET
        is_active = true,
        granted_at = now(),
        granted_by = ${actorId},
        revoked_at = NULL
    `;
  } else {
    await sql`
      UPDATE public.hdc_user_roles
      SET is_active = false, revoked_at = now()
      WHERE user_id = ${targetUserId}
        AND role = ${typedRole}
        AND is_active = true
    `;
  }

  const eventType = action === 'assign'
    ? 'platform_role.manual_assign'
    : 'platform_role.manual_revoke';
  const notificationTitle = action === 'assign'
    ? 'HDC platform role assigned'
    : 'HDC platform role removed';
  const notificationMessage = action === 'assign'
    ? `Your ${typedRole} platform role was assigned by an authorized HDC administrator.`
    : `Your ${typedRole} platform role was removed by an authorized HDC administrator.`;

  await sql.begin(async (tx) => {
    await tx`
      INSERT INTO public.hdc_security_audit (
        user_id, event_type, event_status, metadata
      ) VALUES (
        ${actorId}, ${eventType}, 'success',
        ${tx.json({ targetUserId, role: typedRole, action, reason })}
      )
    `;
    await tx`
      INSERT INTO public.hdc_notifications (
        user_id, event_type, priority, title, message, metadata
      ) VALUES (
        ${targetUserId}, ${eventType}, 'high',
        ${notificationTitle}, ${notificationMessage},
        ${tx.json({ role: typedRole, action, reason })}
      )
    `;
  });

  const roleRows = await sql`
    SELECT role
    FROM public.hdc_user_roles
    WHERE user_id = ${targetUserId}
      AND is_active = true
      AND role::text IN (
        'customer', 'technician', 'seller', 'business', 'supplier', 'store'
      )
    ORDER BY role
  `;

  return json({
    member: {
      id: targetUserId,
      displayName: String(targetRows[0].display_name),
      email: String(targetRows[0].email),
      platformRoles: roleRows.map((row) => String(row.role)),
    },
    change: { role: typedRole, action, reason },
  });
}

async function handle(req: Request): Promise<Response> {
  if (req.method !== 'GET' && req.method !== 'PUT') return methodNotAllowed();
  const sql = openDb();
  try {
    const authorization = await authorize(req, sql);
    if (authorization instanceof Response) return authorization;
    if (req.method === 'GET') return await listMembers(req, sql);
    return await mutateRole(req, sql, authorization.userId);
  } catch (error) {
    console.error('Platform role admin failed', error instanceof Error ? error.message : 'unknown_error');
    return json({ error: 'platform_role_admin_failed' }, 500);
  } finally {
    await closeDb(sql);
  }
}

export default async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return corsPreflightResponse(req);
  return withCors(req, await handle(req));
};

export const config = {
  path: '/api/internal/platform-role-admin',
};
