from __future__ import annotations

import hashlib
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding='utf-8')


def replace(path: str, old: str, new: str, *, count: int = -1) -> None:
    content = read(path)
    if old not in content:
        raise RuntimeError(f'missing expected text in {path}: {old[:100]!r}')
    write(path, content.replace(old, new, count))


def regex_replace(path: str, pattern: str, replacement: str, *, count: int = 1) -> None:
    content = read(path)
    updated, hits = re.subn(pattern, replacement, content, count=count, flags=re.S)
    if hits != count:
        raise RuntimeError(f'expected {count} regex hit(s) in {path}, got {hits}: {pattern[:100]}')
    write(path, updated)


# ---------------------------------------------------------------------------
# Build identity and Build 27 Knowledge Base deferral.
# ---------------------------------------------------------------------------
package = json.loads(read('package.json'))
package['version'] = '0.6.4-build.26'
write('package.json', json.dumps(package, indent=2) + '\n')

lock = json.loads(read('package-lock.json'))
lock['version'] = '0.6.4-build.26'
lock['packages']['']['version'] = '0.6.4-build.26'
write('package-lock.json', json.dumps(lock, indent=2) + '\n')

replace('pubspec.yaml', 'version: 0.6.4+25', 'version: 0.6.4+26')
replace('lib/core/config/app_config.dart', '0.6.4 Beta (Build 25)', '0.6.4 Beta (Build 26)')

kb = read('lib/features/knowledge_base/knowledge_base_screen.dart')
kb = kb.replace('BUILD 26 READY', 'BUILD 27 READY')
kb = kb.replace('implemented in Build 26', 'implemented in Build 27')
kb = kb.replace('Search becomes active in Build 26', 'Search becomes active in Build 27')
kb = kb.replace("'BUILD 26'", "'BUILD 27'")
kb = kb.replace('What Build 26 will activate', 'What Build 27 will activate')
kb = kb.replace('before Build 26 has the backend knowledge authority', 'before Build 27 has the backend knowledge authority')
kb = kb.replace('AVAILABLE IN BUILD 26', 'AVAILABLE IN BUILD 27')
write('lib/features/knowledge_base/knowledge_base_screen.dart', kb)

# Hide unfinished Passport navigation instead of presenting a dead action.
dashboard = read('lib/features/dashboard/dashboard_screen.dart')
dashboard = re.sub(
    r"\n  Future<void> _openPassport\(BuildContext context\) async \{.*?\n  \}\n",
    '\n',
    dashboard,
    count=1,
    flags=re.S,
)
dashboard = re.sub(
    r"\n      HDCNavigationItem\(\n        label: 'HDC Passport',.*?\n      \),",
    '',
    dashboard,
    count=1,
    flags=re.S,
)
dashboard = dashboard.replace('HelpDesk Connect Beta v0.6.4 Build 25', 'HelpDesk Connect Beta v0.6.4 Build 26')
write('lib/features/dashboard/dashboard_screen.dart', dashboard)

# Current client uses the permanent canonical registration URL.
replace('lib/core/auth/hdc_api_auth_gateway.dart', "'/api/auth/register-v2'", "'/api/auth/register'")

# ---------------------------------------------------------------------------
# Shared registration implementation: controlled location + maintenance mode.
# ---------------------------------------------------------------------------
registration = r'''import bcrypt from 'bcryptjs';
import type { DbClient } from './db.mjs';
import { json, methodNotAllowed, readJson } from './http.mjs';
import { normalizeDisplayName, normalizeEmail, normalizePassword } from './validation.mjs';
import {
  RECOVERY_QUESTION_VERSION,
  normalizeRecoveryAnswer,
  parseRecoveryAnswers,
  recoveryAnswerDigest,
} from './account-recovery.mjs';
import { currentRecoveryPepper, operationMode } from './env.mjs';
import { CURRENT_LEGAL_DOCUMENTS, CURRENT_LEGAL_VERSION } from './legal-documents.mjs';
import { normalizeHdcLocation } from './locations.mjs';

export async function handleRegistrationWithDb(
  req: Request,
  sql: DbClient,
  source = 'public_registration',
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  if (operationMode() !== 'normal') {
    return json({
      error: 'service_read_only',
      message: 'HDC account creation is temporarily unavailable while the service is limiting write operations.',
    }, 503, { 'retry-after': '300' });
  }

  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);

  const email = normalizeEmail(body.email);
  const displayName = normalizeDisplayName(body.displayName);
  const password = normalizePassword(body.password);
  const location = normalizeHdcLocation(body.location);
  const recoveryAnswers = parseRecoveryAnswers(body.recoveryAnswers);
  const termsAccepted = body.termsAccepted === true;
  const privacyAcknowledged = body.privacyAcknowledged === true;
  const termsVersion = typeof body.termsVersion === 'string'
    ? body.termsVersion.trim()
    : '';

  if (
    !email || !displayName || !password || !location || !recoveryAnswers ||
    !termsAccepted || !privacyAcknowledged ||
    termsVersion !== CURRENT_LEGAL_VERSION
  ) {
    return json({
      error: 'invalid_registration',
      message: 'Complete the account details, choose a supported HDC location, answer all three recovery questions, and accept the current legal documents.',
    }, 400);
  }

  const prohibitedAnswers = new Set([
    normalizeRecoveryAnswer(email),
    normalizeRecoveryAnswer(displayName),
    normalizeRecoveryAnswer(password),
  ].filter((value): value is string => value !== null));
  if (recoveryAnswers.some((item) => prohibitedAnswers.has(item.answer))) {
    return json({
      error: 'weak_recovery_answers',
      message: 'Recovery answers must not repeat your email, name, or password.',
    }, 400);
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const pepper = currentRecoveryPepper();
  const recoveryHashes = await Promise.all(recoveryAnswers.map(async (item) => ({
    questionCode: item.questionCode,
    pepperKeyId: pepper.keyId,
    answerHash: await bcrypt.hash(
      recoveryAnswerDigest(item.answer, pepper.secret),
      12,
    ),
  })));

  try {
    const createdId = await sql.begin(async (tx) => {
      const rows = await tx`
        INSERT INTO public.hdc_users (email, password_hash, display_name)
        VALUES (${email}, ${passwordHash}, ${displayName})
        RETURNING id
      `;
      const userId = String(rows[0].id);

      await tx`
        INSERT INTO public.hdc_user_roles (user_id, role, is_active)
        VALUES (${userId}, 'customer', true)
        ON CONFLICT (user_id, role)
        DO UPDATE SET is_active = true, revoked_at = NULL
      `;

      for (const item of recoveryHashes) {
        await tx`
          INSERT INTO public.hdc_account_recovery_answers (
            user_id, question_version, question_code, pepper_key_id, answer_hash
          ) VALUES (
            ${userId}, ${RECOVERY_QUESTION_VERSION},
            ${item.questionCode}, ${item.pepperKeyId}, ${item.answerHash}
          )
        `;
      }

      await tx`
        INSERT INTO public.hdc_terms_acceptances (
          user_id, document_type, document_version,
          document_content_sha256, acceptance_method, client_metadata
        ) VALUES
          (
            ${userId}, 'terms_of_service', ${termsVersion},
            ${CURRENT_LEGAL_DOCUMENTS.terms_of_service.contentSha256},
            'registration', ${tx.json({ source })}
          ),
          (
            ${userId}, 'privacy_notice', ${termsVersion},
            ${CURRENT_LEGAL_DOCUMENTS.privacy_notice.contentSha256},
            'registration', ${tx.json({ source })}
          )
      `;

      await tx`
        UPDATE public.hdc_member_profiles
        SET location = ${location}, updated_at = now()
        WHERE user_id = ${userId}
      `;

      await tx`
        INSERT INTO public.hdc_security_audit (
          user_id, event_type, event_status, metadata
        ) VALUES (
          ${userId}, 'auth.register', 'success',
          ${tx.json({ source, location })}
        )
      `;

      return userId;
    });

    const users = await sql`
      SELECT id, public_member_id, email::text AS email, display_name, status,
             email_verified, created_at, updated_at
      FROM public.hdc_users
      WHERE id = ${createdId}
      LIMIT 1
    `;
    const user = users[0];
    return json({
      user: {
        id: String(user.id),
        publicMemberId: String(user.public_member_id),
        email: String(user.email),
        displayName: String(user.display_name),
        status: String(user.status),
        emailVerified: Boolean(user.email_verified),
        roles: ['customer'],
        platformRoles: ['customer'],
        internalRoles: [],
        legalAcceptanceRequired: false,
        legalVersion: CURRENT_LEGAL_VERSION,
        createdAt: new Date(String(user.created_at)).toISOString(),
        updatedAt: new Date(String(user.updated_at)).toISOString(),
      },
    }, 201);
  } catch (error) {
    const code = typeof error === 'object' && error !== null && 'code' in error
      ? String((error as { code?: unknown }).code ?? '')
      : '';
    if (code === '23505') {
      return json({ error: 'email_already_registered' }, 409);
    }
    console.error('Registration failed', error instanceof Error ? error.message : 'unknown_error');
    return json({ error: 'registration_failed' }, 500);
  }
}
'''
write('netlify/functions/_lib/registration.mts', registration)

register_v2 = r'''import { closeDb, openDb } from './_lib/db.mjs';
import { corsPreflightResponse, withCors } from './_lib/cors.mjs';
import { handleRegistrationWithDb } from './_lib/registration.mjs';

export default async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return corsPreflightResponse(req);
  const sql = openDb();
  try {
    const response = await handleRegistrationWithDb(
      req,
      sql,
      'public_registration_v2_compat',
    );
    const headers = new Headers(response.headers);
    headers.set('deprecation', 'true');
    headers.set('link', '</api/auth/register>; rel="successor-version"');
    return withCors(req, new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    }));
  } finally {
    await closeDb(sql);
  }
};

export const config = {
  path: '/api/auth/register-v2',
};
'''
write('netlify/functions/register-v2.mts', register_v2)

# Shared internal-role authorization for current and future privileged tools.
internal_auth = r'''import type { DbClient } from './db.mjs';
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
'''
write('netlify/functions/_lib/internal-auth.mts', internal_auth)

# ---------------------------------------------------------------------------
# Request body cap. 64 KiB is ample for current forms; Build 27 can opt into
# an explicit knowledge-authoring limit when its endpoints are introduced.
# ---------------------------------------------------------------------------
http = read('netlify/functions/_lib/http.mts')
http = re.sub(
    r"export async function readJson\(req: Request\): Promise<Record<string, unknown> \| null> \{.*?\n\}",
    r'''export const DEFAULT_MAX_JSON_REQUEST_BYTES = 64 * 1024;

export async function readJson(
  req: Request,
  maxBytes = DEFAULT_MAX_JSON_REQUEST_BYTES,
): Promise<Record<string, unknown> | null> {
  const contentLength = req.headers.get('content-length');
  if (contentLength) {
    const declared = Number(contentLength);
    if (Number.isFinite(declared) && declared > maxBytes) return null;
  }

  try {
    const reader = req.body?.getReader();
    if (!reader) return null;
    const decoder = new TextDecoder();
    let received = 0;
    let text = '';
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      received += value.byteLength;
      if (received > maxBytes) {
        await reader.cancel();
        return null;
      }
      text += decoder.decode(value, { stream: true });
    }
    text += decoder.decode();
    const value = JSON.parse(text);
    return value && typeof value === 'object' && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}''',
    http,
    count=1,
    flags=re.S,
)
write('netlify/functions/_lib/http.mts', http)

# ---------------------------------------------------------------------------
# API consolidation, login timing hardening, readiness, Build 26 identity.
# ---------------------------------------------------------------------------
api = read('netlify/functions/api.mts')
if "./_lib/registration.mjs" not in api:
    api = api.replace(
        "import { normalizeDisplayName, normalizeEmail, normalizePassword } from './_lib/validation.mjs';",
        "import { normalizeEmail, normalizePassword } from './_lib/validation.mjs';\nimport { handleRegistrationWithDb } from './_lib/registration.mjs';",
    )
api = re.sub(
    r"async function handleRegister\(req: Request, sql: DbClient\): Promise<Response> \{.*?\n\}\n\nasync function handleRecoveryStart",
    "async function handleRegister(req: Request, sql: DbClient): Promise<Response> {\n  return await handleRegistrationWithDb(req, sql, 'public_registration');\n}\n\nasync function handleRecoveryStart",
    api,
    count=1,
    flags=re.S,
)
api = api.replace(
    "const valid = row ? await bcrypt.compare(password, String(row.password_hash)) : false;",
    "const valid = await bcrypt.compare(\n    password,\n    row ? String(row.password_hash) : DUMMY_RECOVERY_HASH,\n  );",
)
api = api.replace("build: '0.6.4-build25'", "build: '0.6.4-build26'")
# Add a latest-schema readiness check. 0021 depends on 0017-0020.
needle = "        EXISTS (\n          SELECT 1\n          FROM pg_roles\n          WHERE rolname = 'hdc_app'"
if needle not in api:
    raise RuntimeError('readiness insertion point missing')
api = api.replace(
    needle,
    "        (\n          to_regclass('public.hdc_public_news_posts') IS NOT NULL AND\n          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0017') AND\n          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0018') AND\n          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0019') AND\n          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0020') AND\n          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0021')\n        ) AS latest_schema_ready,\n        EXISTS (\n          SELECT 1\n          FROM pg_roles\n          WHERE rolname = 'hdc_app'",
    1,
)
api = api.replace(
    "      authority.legal_records_ready === true &&\n      authority.workflow_role_ready === true &&",
    "      authority.legal_records_ready === true &&\n      authority.latest_schema_ready === true &&\n      authority.workflow_role_ready === true &&",
    1,
)
api = api.replace(
    "          legalRecords:\n            authority.legal_records_ready === true ? 'ok' : 'not_ready',",
    "          legalRecords:\n            authority.legal_records_ready === true ? 'ok' : 'not_ready',\n          latestSchema:\n            authority.latest_schema_ready === true ? 'ok' : 'not_ready',",
    1,
)
api = api.replace(
    "        legalRecords: 'ok',\n      },",
    "        legalRecords: 'ok',\n        latestSchema: 'ok',\n      },",
    1,
)
write('netlify/functions/api.mts', api)

# ---------------------------------------------------------------------------
# News authorization, consent evidence, immutable published history.
# ---------------------------------------------------------------------------
news_admin = read('netlify/functions/news-admin.mts')
news_admin = news_admin.replace("import { verifySessionToken } from './_lib/session.mjs';\n", '')
news_admin = news_admin.replace("import { bearerToken, json, methodNotAllowed, readJson } from './_lib/http.mjs';", "import { json, methodNotAllowed, readJson } from './_lib/http.mjs';")
if "internal-auth.mjs" not in news_admin:
    news_admin = news_admin.replace(
        "import { operationMode } from './_lib/env.mjs';",
        "import { operationMode } from './_lib/env.mjs';\nimport { authorizeInternalRequest } from './_lib/internal-auth.mjs';",
    )
news_admin = re.sub(
    r"async function authorize\(.*?\n\}\n\nfunction view",
    "async function authorize(req: Request, sql: DbClient) {\n  return await authorizeInternalRequest(\n    req,\n    sql,\n    privilegedInternalRoles,\n    'news_management_forbidden',\n  );\n}\n\nfunction view",
    news_admin,
    count=1,
    flags=re.S,
)
news_admin = news_admin.replace(
    "    recognitionConsentConfirmed: Boolean(row.recognition_consent_confirmed),\n    publishedAt:",
    "    recognitionConsentConfirmed: Boolean(row.recognition_consent_confirmed),\n    recognitionConsentAt: row.recognition_consent_at == null ? null : String(row.recognition_consent_at),\n    recognitionConsentMethod: row.recognition_consent_method == null ? null : String(row.recognition_consent_method),\n    recognitionConsentScope: row.recognition_consent_scope == null ? null : String(row.recognition_consent_scope),\n    recognitionConsentReference: row.recognition_consent_reference == null ? null : String(row.recognition_consent_reference),\n    everPublished: Boolean(row.ever_published),\n    publishedAt:",
)
news_admin = news_admin.replace(
    "  const recognitionConsentConfirmed = body.recognitionConsentConfirmed === true;\n  const isPinned",
    "  const recognitionConsentConfirmed = body.recognitionConsentConfirmed === true;\n  const recognitionConsentMethod = cleanText(body.recognitionConsentMethod, 40);\n  const recognitionConsentScope = cleanText(body.recognitionConsentScope, 500);\n  const recognitionConsentReference = cleanText(body.recognitionConsentReference, 500);\n  const isPinned",
)
news_admin = news_admin.replace(
    "    (!recognitionConsentConfirmed || recognitionSubject.length < 2)\n  )",
    "    (!recognitionConsentConfirmed || recognitionSubject.length < 2 ||\n      recognitionConsentMethod.length < 2 || recognitionConsentScope.length < 3)\n  )",
)
news_admin = news_admin.replace(
    "    recognitionConsentConfirmed,\n    isPinned,",
    "    recognitionConsentConfirmed,\n    recognitionConsentMethod: recognitionConsentMethod || null,\n    recognitionConsentScope: recognitionConsentScope || null,\n    recognitionConsentReference: recognitionConsentReference || null,\n    isPinned,",
)
# Expand SELECT/RETURNING projections.
news_admin = news_admin.replace(
    "recognition_subject, recognition_consent_confirmed,\n      published_at, created_at, updated_at",
    "recognition_subject, recognition_consent_confirmed, recognition_consent_at,\n      recognition_consent_method, recognition_consent_scope, recognition_consent_reference,\n      ever_published, published_at, created_at, updated_at",
)
news_admin = news_admin.replace(
    "recognition_subject, recognition_consent_confirmed,\n        published_at, created_by, updated_by",
    "recognition_subject, recognition_consent_confirmed, recognition_consent_method,\n        recognition_consent_scope, recognition_consent_reference,\n        published_at, created_by, updated_by",
)
news_admin = news_admin.replace(
    "${parsed.recognitionConsentConfirmed},\n        ${parsed.status === 'published' ? new Date() : null},",
    "${parsed.recognitionConsentConfirmed}, ${parsed.recognitionConsentMethod},\n        ${parsed.recognitionConsentScope}, ${parsed.recognitionConsentReference},\n        ${parsed.status === 'published' ? new Date() : null},",
)
news_admin = news_admin.replace(
    "recognition_consent_confirmed = ${parsed.recognitionConsentConfirmed},\n        published_at = CASE",
    "recognition_consent_confirmed = ${parsed.recognitionConsentConfirmed},\n        recognition_consent_method = ${parsed.recognitionConsentMethod},\n        recognition_consent_scope = ${parsed.recognitionConsentScope},\n        recognition_consent_reference = ${parsed.recognitionConsentReference},\n        recognition_consent_at = CASE\n          WHEN ${parsed.kind} = 'recognition' AND ${parsed.recognitionConsentConfirmed} = true\n            THEN COALESCE(recognition_consent_at, now())\n          ELSE recognition_consent_at\n        END,\n        published_at = CASE",
)
news_admin = news_admin.replace(
    "      WHERE id = ${id}\n        AND status <> 'published'",
    "      WHERE id = ${id}\n        AND status <> 'published'\n        AND published_at IS NULL\n        AND ever_published = false",
)
news_admin = news_admin.replace(
    "message: 'Published posts must be archived before deletion.',",
    "message: 'Only never-published drafts can be deleted. Published history must be archived and retained.',",
)
write('netlify/functions/news-admin.mts', news_admin)

# Platform role tool now uses the same internal authorization helper.
role_admin = read('netlify/functions/platform-role-admin.mts')
role_admin = role_admin.replace("import { verifySessionToken } from './_lib/session.mjs';\n", '')
role_admin = role_admin.replace("import { bearerToken, json, methodNotAllowed, readJson } from './_lib/http.mjs';", "import { json, methodNotAllowed, readJson } from './_lib/http.mjs';")
if "internal-auth.mjs" not in role_admin:
    role_admin = role_admin.replace(
        "import { operationMode } from './_lib/env.mjs';",
        "import { operationMode } from './_lib/env.mjs';\nimport { authorizeInternalRequest } from './_lib/internal-auth.mjs';",
    )
role_admin = re.sub(
    r"async function authorize\(.*?\n\}\n\nfunction memberView",
    "async function authorize(req: Request, sql: DbClient) {\n  return await authorizeInternalRequest(\n    req,\n    sql,\n    privilegedInternalRoles,\n    'platform_role_management_forbidden',\n  );\n}\n\nfunction memberView",
    role_admin,
    count=1,
    flags=re.S,
)
write('netlify/functions/platform-role-admin.mts', role_admin)

# News model/provider/client evidence fields.
model = read('lib/models/hdc_news_post.dart')
model = model.replace(
    "  final bool recognitionConsentConfirmed;\n  final DateTime? publishedAt;",
    "  final bool recognitionConsentConfirmed;\n  final DateTime? recognitionConsentAt;\n  final String? recognitionConsentMethod;\n  final String? recognitionConsentScope;\n  final String? recognitionConsentReference;\n  final bool everPublished;\n  final DateTime? publishedAt;",
)
model = model.replace(
    "    required this.recognitionConsentConfirmed,\n    required this.updatedAt,",
    "    required this.recognitionConsentConfirmed,\n    required this.everPublished,\n    required this.updatedAt,\n    this.recognitionConsentAt,\n    this.recognitionConsentMethod,\n    this.recognitionConsentScope,\n    this.recognitionConsentReference,",
)
model = model.replace(
    "      recognitionConsentConfirmed:\n          json['recognitionConsentConfirmed'] == true,\n      publishedAt:",
    "      recognitionConsentConfirmed:\n          json['recognitionConsentConfirmed'] == true,\n      recognitionConsentAt: _date(json['recognitionConsentAt']),\n      recognitionConsentMethod: json['recognitionConsentMethod'] is String\n          ? (json['recognitionConsentMethod'] as String).trim()\n          : null,\n      recognitionConsentScope: json['recognitionConsentScope'] is String\n          ? (json['recognitionConsentScope'] as String).trim()\n          : null,\n      recognitionConsentReference: json['recognitionConsentReference'] is String\n          ? (json['recognitionConsentReference'] as String).trim()\n          : null,\n      everPublished: json['everPublished'] == true || json['publishedAt'] != null,\n      publishedAt:",
)
write('lib/models/hdc_news_post.dart', model)

provider = read('lib/providers/hdc_news_provider.dart')
provider = provider.replace(
    "    String? recognitionSubject,\n    required bool recognitionConsentConfirmed,",
    "    String? recognitionSubject,\n    required bool recognitionConsentConfirmed,\n    String? recognitionConsentMethod,\n    String? recognitionConsentScope,\n    String? recognitionConsentReference,",
)
provider = provider.replace(
    "        'recognitionConsentConfirmed': recognitionConsentConfirmed,",
    "        'recognitionConsentConfirmed': recognitionConsentConfirmed,\n        'recognitionConsentMethod': recognitionConsentMethod?.trim(),\n        'recognitionConsentScope': recognitionConsentScope?.trim(),\n        'recognitionConsentReference': recognitionConsentReference?.trim(),",
)
provider = provider.replace(
    "    if (post.status == HdcNewsStatus.published) {",
    "    if (post.status == HdcNewsStatus.published || post.everPublished) {",
)
provider = provider.replace(
    "message: 'Archive a published post before deleting it.',",
    "message: 'Published history is retained. Only a never-published draft can be deleted.',",
)
write('lib/providers/hdc_news_provider.dart', provider)

management = read('lib/features/news/news_management_screen.dart')
management = management.replace(
    "  late final TextEditingController _recognitionSubject;",
    "  late final TextEditingController _recognitionSubject;\n  late final TextEditingController _recognitionScope;\n  late final TextEditingController _recognitionReference;",
)
management = management.replace(
    "  late bool _recognitionConsent;",
    "  late bool _recognitionConsent;\n  late String _recognitionConsentMethod;",
)
management = management.replace(
    "    _kind = post?.kind ?? HdcNewsKind.announcement;",
    "    _recognitionScope = TextEditingController(\n      text: post?.recognitionConsentScope ?? 'Public HDC News recognition',\n    );\n    _recognitionReference = TextEditingController(\n      text: post?.recognitionConsentReference ?? '',\n    );\n    _kind = post?.kind ?? HdcNewsKind.announcement;",
)
management = management.replace(
    "    _recognitionConsent = post?.recognitionConsentConfirmed ?? false;",
    "    _recognitionConsent = post?.recognitionConsentConfirmed ?? false;\n    _recognitionConsentMethod = post?.recognitionConsentMethod ?? 'email';",
)
management = management.replace(
    "    _recognitionSubject.dispose();",
    "    _recognitionSubject.dispose();\n    _recognitionScope.dispose();\n    _recognitionReference.dispose();",
)
management = management.replace(
    "            recognitionConsentConfirmed:\n                _kind == HdcNewsKind.recognition && _recognitionConsent,",
    "            recognitionConsentConfirmed:\n                _kind == HdcNewsKind.recognition && _recognitionConsent,\n            recognitionConsentMethod:\n                _kind == HdcNewsKind.recognition ? _recognitionConsentMethod : null,\n            recognitionConsentScope:\n                _kind == HdcNewsKind.recognition ? _recognitionScope.text : null,\n            recognitionConsentReference:\n                _kind == HdcNewsKind.recognition ? _recognitionReference.text : null,",
)
management = management.replace(
    "                      const SizedBox(height: 4),\n                      CheckboxListTile(",
    "                      const SizedBox(height: 10),\n                      DropdownButtonFormField<String>(\n                        initialValue: _recognitionConsentMethod,\n                        decoration: const InputDecoration(\n                          labelText: 'Consent method',\n                          helperText: 'Record how public-recognition permission was obtained.',\n                        ),\n                        items: const [\n                          DropdownMenuItem(value: 'email', child: Text('Email')),\n                          DropdownMenuItem(value: 'written_message', child: Text('Written message / chat')),\n                          DropdownMenuItem(value: 'platform_message', child: Text('HDC platform message')),\n                          DropdownMenuItem(value: 'other', child: Text('Other documented method')),\n                        ],\n                        onChanged: saving ? null : (value) {\n                          if (value != null) setState(() => _recognitionConsentMethod = value);\n                        },\n                      ),\n                      const SizedBox(height: 14),\n                      TextFormField(\n                        controller: _recognitionScope,\n                        maxLength: 500,\n                        decoration: const InputDecoration(\n                          labelText: 'Approved recognition scope',\n                          helperText: 'Describe what they agreed HDC may publish.',\n                        ),\n                        validator: (value) {\n                          if (_status != HdcNewsStatus.published) return null;\n                          return (value?.trim().length ?? 0) < 3\n                              ? 'Record the approved public-recognition scope.'\n                              : null;\n                        },\n                      ),\n                      const SizedBox(height: 14),\n                      TextFormField(\n                        controller: _recognitionReference,\n                        maxLength: 500,\n                        decoration: const InputDecoration(\n                          labelText: 'Internal consent reference (optional)',\n                          helperText: 'Example: email date, message reference, or internal note. This is never public.',\n                        ),\n                      ),\n                      const SizedBox(height: 4),\n                      CheckboxListTile(",
    1,
)
management = management.replace(
    "    if (post == null || post.status == HdcNewsStatus.published) return;",
    "    if (post == null || post.status == HdcNewsStatus.published || post.everPublished) return;",
)
management = management.replace(
    "'This permanently deletes the draft or archived post. Published posts must be archived first.'",
    "'This permanently deletes a draft that has never been published. Published history is archived and retained.'",
)
management = management.replace(
    "widget.existing!.status != HdcNewsStatus.published)",
    "widget.existing!.status != HdcNewsStatus.published &&\n                            !widget.existing!.everPublished)",
)
write('lib/features/news/news_management_screen.dart', management)

# ---------------------------------------------------------------------------
# News history/consent migration.
# ---------------------------------------------------------------------------
migration_0020 = r'''-- HDC Build 26: durable public-news history and recognition-consent evidence.
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_public_news_posts') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0019'
     ) THEN
    RAISE EXCEPTION 'HDC migration 0019 must be applied first';
  END IF;
END
$$;

ALTER TABLE public.hdc_public_news_posts
  ADD COLUMN IF NOT EXISTS recognition_consent_at timestamptz,
  ADD COLUMN IF NOT EXISTS recognition_consent_method text,
  ADD COLUMN IF NOT EXISTS recognition_consent_scope varchar(500),
  ADD COLUMN IF NOT EXISTS recognition_consent_reference varchar(500),
  ADD COLUMN IF NOT EXISTS ever_published boolean NOT NULL DEFAULT false;

UPDATE public.hdc_public_news_posts
SET
  ever_published = true,
  recognition_consent_at = CASE
    WHEN kind = 'recognition' AND recognition_consent_confirmed = true
      THEN COALESCE(recognition_consent_at, published_at, created_at)
    ELSE recognition_consent_at
  END,
  recognition_consent_method = CASE
    WHEN kind = 'recognition' AND recognition_consent_confirmed = true
      THEN COALESCE(recognition_consent_method, 'legacy_confirmation')
    ELSE recognition_consent_method
  END,
  recognition_consent_scope = CASE
    WHEN kind = 'recognition' AND recognition_consent_confirmed = true
      THEN COALESCE(recognition_consent_scope, 'Public HDC News recognition')
    ELSE recognition_consent_scope
  END,
  recognition_consent_reference = CASE
    WHEN kind = 'recognition' AND recognition_consent_confirmed = true
      THEN COALESCE(recognition_consent_reference, 'Migrated from Build 25 consent confirmation')
    ELSE recognition_consent_reference
  END
WHERE published_at IS NOT NULL OR recognition_consent_confirmed = true;

ALTER TABLE public.hdc_public_news_posts
  DROP CONSTRAINT IF EXISTS hdc_public_news_recognition_consent_evidence;
ALTER TABLE public.hdc_public_news_posts
  ADD CONSTRAINT hdc_public_news_recognition_consent_evidence CHECK (
    kind <> 'recognition'
    OR status <> 'published'
    OR (
      recognition_consent_confirmed = true
      AND recognition_consent_at IS NOT NULL
      AND recognition_consent_method IS NOT NULL
      AND length(btrim(recognition_consent_method)) BETWEEN 2 AND 40
      AND recognition_consent_scope IS NOT NULL
      AND length(btrim(recognition_consent_scope)) BETWEEN 3 AND 500
    )
  );

ALTER TABLE public.hdc_public_news_posts
  DROP CONSTRAINT IF EXISTS hdc_public_news_recognition_consent_method;
ALTER TABLE public.hdc_public_news_posts
  ADD CONSTRAINT hdc_public_news_recognition_consent_method CHECK (
    recognition_consent_method IS NULL
    OR recognition_consent_method IN (
      'email', 'written_message', 'platform_message', 'other',
      'legacy_confirmation'
    )
  );

CREATE OR REPLACE FUNCTION public.hdc_public_news_lifecycle_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.ever_published = true OR OLD.published_at IS NOT NULL THEN
      RAISE EXCEPTION 'Published HDC news history must be archived and retained';
    END IF;
    RETURN OLD;
  END IF;

  IF NEW.status = 'published' THEN
    NEW.ever_published := true;
    IF NEW.kind = 'recognition' AND NEW.recognition_consent_confirmed = true THEN
      NEW.recognition_consent_at := COALESCE(
        NEW.recognition_consent_at,
        OLD.recognition_consent_at,
        now()
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.hdc_public_news_lifecycle_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_public_news_lifecycle_guard() TO hdc_app;

DROP TRIGGER IF EXISTS hdc_public_news_lifecycle_guard
  ON public.hdc_public_news_posts;
CREATE TRIGGER hdc_public_news_lifecycle_guard
BEFORE INSERT OR UPDATE OR DELETE ON public.hdc_public_news_posts
FOR EACH ROW EXECUTE FUNCTION public.hdc_public_news_lifecycle_guard();

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0020', 'build26_news_consent_history', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
'''
write('migrations/0020_build26_news_consent_history.sql', migration_0020)

# ---------------------------------------------------------------------------
# Material legal update for public News/recognition and future PHP support.
# ---------------------------------------------------------------------------
terms = '''HELPDESK CONNECT BETA TERMS OF SERVICE
Version: beta-2026-09-06
Effective: 6 September 2026

1. WHO OPERATES THIS BETA

HelpDesk Connect (HDC) is a controlled beta technology-support and marketplace project represented by the HDC Owner. The Support HDC page may use the SaiCore name as the project/support identity. This does not by itself represent that SaiCore or HDC is already a separately incorporated company.

For legal, privacy, security, sponsorship, or owner-level concerns, contact the HDC Owner at saicore.holdings@gmail.com. Registered members should use HDC transaction, dispute, privacy, and account tools when those tools are the appropriate record of the issue.

2. ACCEPTANCE AND ELIGIBILITY

By creating an account, renewing acceptance after a material update, or using an account after acceptance, you agree to these Terms and acknowledge the current Privacy Notice. You must be at least 18 years old and legally able to enter contracts, or act through a parent or legal guardian who accepts responsibility for the account and transaction.

Guest access is limited to public or preview features HDC makes available. Posting requests, making offers, starting a transaction, messaging a participant, or requesting a product requires a registered account and may require an approved role.

3. BETA STATUS

HDC is under active development. Features may change, become temporarily unavailable, or be removed after notice. The beta may contain defects. HDC will use reasonable care to preserve authoritative account and transaction data, but this beta is not an emergency service, safety dispatch service, payment institution, bank, insurer, employer, or substitute for professional advice.

HDC may place the service in read-only, maintenance, or incident mode to protect users or data. Planned changes will preserve records where reasonably possible. Non-critical failures should not disable unrelated core functions.

4. ACCOUNTS, SECURITY, AND ROLES

You must provide accurate account information, protect your password and recovery answers, and promptly report suspected unauthorized access. You may not share credentials, impersonate another person, create deceptive identities, or attempt to obtain internal HDC permissions.

Public registration grants only the Customer role. Technician, Business, Seller, Supplier, and Store capabilities require an application and approval. Internal Owner, Super Admin, Admin, and Moderator authority is private and cannot be self-assigned.

HDC may suspend a role or account when reasonably necessary to investigate fraud, abuse, unsafe activity, security incidents, legal obligations, or serious violations. Where appropriate, HDC will preserve relevant evidence and provide a review path.

5. HDC AS A CONNECTING PLATFORM

HDC helps customers discover independent technicians, businesses, sellers, suppliers, and stores. Unless HDC expressly identifies itself as the provider or seller, the service or product contract is between the participating customer and provider or merchant. HDC does not employ, control, or guarantee independent participants merely because they appear on the platform.

Profiles, approvals, badges, counts, rankings, or status labels are informational controls and are not guarantees of identity, skill, licensing, availability, product condition, or outcome. Participants must perform their own reasonable checks. Nothing in these Terms removes rights or remedies that cannot lawfully be waived under Philippine consumer law.

6. AUTHORITATIVE TRANSACTION RECORDS

HDC records the lifecycle of service and marketplace activity to support tracking, receipts, accountability, safety reviews, and disputes. Depending on the feature, the authoritative record may include service requests, proposals, acceptance decisions, participant identities and snapshots, schedules, change orders, exceptions, status changes, transaction messages, external-payment attestations, confirmations, refunds, receipts, structured documents, dispute evidence, and resolution events.

Participants must not falsify, backdate, conceal, or manipulate transaction records. A dashboard shortcut or local display may be removed without deleting the authoritative backend record. Completed, cancelled, or disputed records may remain available when needed for participant history, security, legal compliance, backup integrity, or dispute handling.

HDC records are evidence of actions reported or performed through HDC. They do not automatically prove that physical work, delivery, payment, product quality, or legal obligations were completed outside the platform.

7. SERVICE REQUESTS, OFFERS, AND WORK

Customers must describe problems, locations, timing, and known safety concerns honestly. Technicians must provide realistic diagnoses, prices, parts arrangements, schedules, warranties, and qualifications. An accepted offer creates an HDC service transaction between its recorded participants.

Changes to price, scope, schedule, or completion should be recorded through the transaction workspace. Participants should not use private side arrangements to defeat HDC safety, evidence, or dispute controls.

Do not rely on HDC for emergencies. Stop troubleshooting and contact qualified emergency services or licensed professionals where there is fire, smoke, exposed mains electricity, gas, structural danger, violence, medical risk, or another immediate threat. Technology-related power guidance is limited to appropriate device, UPS, PoE, and low-risk diagnostics; regulated or high-risk electrical work must be handled by a properly qualified person.

8. PRODUCTS AND MARKETPLACE ACTIVITY

Listings and purchase requests must accurately describe the item, price, quantity, condition, compatibility, stock, ownership, warranty, and material limitations. Prohibited, stolen, counterfeit, unsafe, regulated, or non-technology items may not be listed.

Current beta purchase requests and stock allocations are not payment-confirmed checkout or proof of delivery. Future order and fulfillment features may add additional terms before activation. Merchants and consumers remain responsible for applicable disclosures, warranties, receipts, taxes, delivery obligations, and remedies under law.

9. PAYMENTS, RECEIPTS, REFUNDS, AND SUPPORT CONTRIBUTIONS

HDC currently records participant statements about service or marketplace payments completed through external channels; it does not collect card, bank, wallet, PIN, OTP, or online-banking credentials. Never send those credentials through HDC chat, documents, notes, News, or owner-contact messages.

The Support HDC page may later display verified SaiCore-controlled QR or wallet destinations for voluntary PHP support. Support may include one-time contributions, recurring support where an approved channel permits it, or separately discussed corporate sponsorships. Bank transfer may remain unavailable until HDC explicitly enables and verifies it.

A voluntary contribution does not buy an HDC rating, verification, moderation exception, dispute advantage, access to private data, privileged platform authority, or a guaranteed product decision. Corporate sponsorship terms that create separate deliverables must be agreed separately and do not override HDC safety, privacy, moderation, or transaction rules.

External wallet or payment providers may charge their own fees. HDC will not describe a payment route as fee-free unless that statement is accurate for the relevant use. HDC is not the external payment provider and does not request wallet PINs, OTPs, passwords, or banking credentials.

10. PUBLIC NEWS AND SUPPORTER RECOGNITION

HDC may publish public News for features, maintenance, announcements, and other platform information. Authorized Owner, Super Admin, or Admin accounts may create and manage these posts. Published News history may be archived while remaining part of HDC's operational record.

HDC will not publicly name a supporter or sponsor in a recognition post unless public-recognition consent has been recorded. The approved public display name and scope of that consent must be respected. Recognition is informational appreciation only and is not a trust, verification, ranking, or preferential-treatment signal.

11. MESSAGING, DOCUMENTS, AND CONDUCT

Private transaction messaging is available only to authorized transaction participants. Offensive language may require an explicit warning acknowledgment. Threats, targeted harassment, fraud, credential theft, illegal content, sexual exploitation, malicious code, and attempts to evade safety controls are prohibited.

Do not upload or send secrets, passwords, payment credentials, unnecessary identification documents, or another person's personal data without authority. HDC may preserve, restrict, or disclose relevant records when reasonably necessary for participant safety, moderation, disputes, security, or legal compliance.

12. DISPUTES

Participants should first use the transaction workspace to record the issue and preserve relevant evidence. Opening a dispute may freeze mutable service or payment actions. Authorized HDC reviewers may record a platform resolution based on available evidence, including continuation, completion, cancellation, or refund-related outcomes.

An HDC resolution governs the platform record and available HDC actions. It does not prevent either party from exercising non-waivable consumer rights, reporting unlawful conduct, or pursuing a remedy before an appropriate government agency, court, payment provider, or other authority.

13. ACCEPTABLE USE

You may not use HDC to break the law; harm people or systems; gain unauthorized access; distribute malware; scrape private data; interfere with availability; manipulate reviews, offers, inventory, recognition, or disputes; evade account restrictions; infringe intellectual property; or offer work, goods, or advice you are not legally permitted or qualified to provide.

Security research must not access another person's data or disrupt the service. Report suspected vulnerabilities privately to the HDC Owner.

14. CONTENT AND INTELLECTUAL PROPERTY

You retain ownership of content you lawfully submit. You grant HDC a limited, non-exclusive license to store, process, reproduce, and display that content only as needed to operate, secure, improve, back up, and administer the beta and its transactions. You must have the right to submit the content.

HDC software, branding, interfaces, and original platform materials remain protected by applicable intellectual-property law. These Terms do not grant permission to copy, resell, reverse engineer, or misuse them except where law expressly permits.

15. AVAILABILITY, WARRANTIES, AND LIABILITY

HDC will use reasonable care appropriate to a controlled beta but provides the beta on an as-available basis. To the fullest extent permitted by law, HDC does not promise uninterrupted availability or guarantee the conduct, identity, work, goods, statements, support recognition, or outcomes of independent participants.

Nothing in these Terms excludes liability or a remedy that Philippine law does not allow to be excluded. Subject to that rule, each participant remains responsible for their own conduct, representations, products, services, taxes, licenses, safety obligations, and agreements with other participants.

16. ENDING USE

You may stop using HDC at any time. Account deletion, privacy, and data-access requests may be submitted through Account Security. HDC may retain limited records where necessary for security, fraud prevention, active disputes, transaction integrity, published News history, recognition-consent evidence, backup recovery, or legal obligations, as explained in the Privacy Notice.

17. CHANGES TO THESE TERMS

HDC may update these Terms as the beta develops. Material changes require a new version and renewed acceptance before protected account functions continue. The accepted version and time are recorded. Editorial changes that do not alter rights or purposes may be clarified without retroactively changing an accepted transaction.

18. GOVERNING LAW

These Terms are governed by the laws of the Republic of the Philippines, without removing mandatory rights or jurisdiction available to consumers or data subjects. Electronic records and acceptances may be recognized as electronic documents under applicable Philippine law.

LEGAL REFERENCES

Data Privacy Act of 2012 (Republic Act No. 10173): https://privacy.gov.ph/data-privacy-act/
Electronic Commerce Act of 2000 (Republic Act No. 8792): https://lawphil.net/statutes/repacts/ra2000/ra_8792_2000.html
Consumer Act of the Philippines (Republic Act No. 7394): https://lawphil.net/statutes/repacts/ra1992/ra_7394_1992.html
Internet Transactions Act of 2023 (Republic Act No. 11967): https://lawphil.net/statutes/repacts/ra2023/ra_11967_2023.html
'''
privacy = '''HELPDESK CONNECT BETA PRIVACY NOTICE
Version: beta-2026-09-06
Effective: 6 September 2026

1. CONTROLLER AND CONTACT

The personal information controller for this controlled beta is the HelpDesk Connect (HDC) beta project, represented by the HDC Owner and Privacy Representative. The Support HDC page may use SaiCore as the project/support identity; HDC is not yet presented as a separately incorporated company.

Registered members may exercise privacy rights through Account Security > Privacy Request. If you cannot sign in, or for an owner-level privacy or security concern, contact saicore.holdings@gmail.com. HDC will verify identity before disclosing, correcting, exporting, or deleting account data.

2. SCOPE

This Notice explains how HDC collects, uses, stores, shares, protects, and disposes of personal data through the website, API, test applications, account recovery, service marketplace, product marketplace, transaction workspace, messaging, documents, payment attestations, dispute handling, public News, supporter recognition, Support HDC, and owner contact.

It applies to guests, registered members, customers, technicians, businesses, sellers, suppliers, stores, supporters, sponsors, internal reviewers, and people whose information is lawfully included in a transaction or public recognition. Independent providers and merchants may separately control information they collect outside HDC and should provide their own notices where required.

3. DATA HDC PROCESSES

Account and security data may include your internal UUID, public member reference, email address, display name, account status, approved roles, password hash, protected recovery-answer hashes, reset-token records, session identifiers, user agent, login and recovery events, security audit metadata, and timestamps. HDC never stores plaintext passwords or plaintext recovery answers.

Profile and application data may include biography, service area, public name, role-specific qualifications, skills, business or store details, contact preferences, application answers, reviewer decisions, and fields you choose to publish. Only fields clearly marked public are intended for public discovery.

Service and marketplace data may include requests, descriptions, device or product details, locations, schedules, budgets, offers, prices, parts arrangements, warranties, inventory, purchase requests, participant snapshots, status history, change orders, exceptions, and completion information.

Transaction and support data may include private messages, warning acknowledgments, structured documents, payment and refund attestations, receipts, dispute reasons, evidence descriptions, resolution events, notifications, and activity history. Do not submit passwords, OTPs, PINs, card data, bank credentials, wallet credentials, or unnecessary government identification.

Public News data may include announcement text, feature and maintenance notices, publication status, author/reviewer identifiers, and publication history. If a supporter or sponsor agrees to public recognition, HDC may store the approved public display name, consent status, consent time, consent method, approved recognition scope, and an internal consent reference. Internal consent evidence is not published in the public News feed.

Support and sponsorship data may include information voluntarily sent to the HDC Owner, such as supporter or organization name, contact information, proposal details, and transaction confirmation the sender chooses to provide. HDC does not request wallet PINs, OTPs, passwords, online-banking credentials, or private keys. If verified QR or wallet destinations are later displayed, payment processing remains with the external provider.

Technical data may include request identifiers, timestamps, browser or application information, security and diagnostic logs, and network information made available by the hosting environment. HDC does not currently use advertising trackers or sell personal data.

4. PURPOSES AND LEGAL BASES

HDC processes data to create and secure accounts; authenticate sessions; recover access; administer roles; publish information you choose or authorize to make public; connect customers and providers; create and preserve transaction records; operate messaging, notifications, receipts, documents, disputes, News and recognition; respond to support and sponsorship inquiries; prevent fraud and abuse; investigate incidents; maintain backups; comply with law; and improve reliability.

Processing is based, as applicable, on your consent or acknowledgment, steps requested before a transaction, performance of the HDC service and participant transactions, compliance with legal obligations, protection of vital interests and platform safety, and legitimate interests such as security, fraud prevention, dispute evidence, service integrity, public release history, and controlled-beta improvement. HDC will not reuse personal data for an incompatible purpose without a lawful basis and appropriate notice.

5. HOW DATA IS COLLECTED

HDC receives data directly from you; from another participant when necessary for a shared transaction; from authorized internal reviewers; from supporters or sponsors who contact HDC; from application and server activity; and from hosting, database, or security providers that support HDC. Client-supplied identity or role claims are not trusted as authority; the server verifies account, role, and participant relationships.

6. DISCLOSURE AND RECIPIENTS

Transaction participants receive the information necessary to evaluate and perform their shared request, offer, purchase request, service, message, receipt, document, or dispute. Public visitors may see active product listings, deliberately published profile fields, public News, and supporter or sponsor recognition only when public-recognition consent has been recorded.

Authorized HDC personnel may access the minimum information needed for role reviews, account recovery, security, moderation, privacy requests, disputes, News administration, recognition-consent verification, incident response, and system administration. Internal roles, private consent references, and private operational data are not public fields.

HDC uses service providers acting as processors or infrastructure providers, currently including Netlify for web and serverless hosting and Neon PostgreSQL for database hosting. External wallet or payment providers control payment information processed through their own systems. HDC may disclose information when required by lawful process, to protect people or systems, or to investigate suspected unlawful conduct.

HDC does not sell personal data and does not disclose it for third-party behavioral advertising.

7. INTERNATIONAL PROCESSING

Current infrastructure providers may process or store data outside the Philippines, including in the United States. HDC limits data sent to providers, keeps database credentials out of client applications, uses encrypted transport, applies access controls and row-level security, and maintains provider-neutral backup and migration controls. Cross-border processing remains subject to the Data Privacy Act, applicable safeguards, and provider obligations.

8. STORAGE AND RETENTION

Authoritative account, role, transaction, message, document, receipt, audit, dispute, News, and recognition-consent records are stored in the HDC backend rather than relying on a device-only copy. Closing or uninstalling an application may remove local state but does not automatically delete authoritative records.

During the controlled beta, HDC retains active-account and transaction records for the beta's duration and for up to 12 months after the beta closes, unless a shorter period is implemented or a longer period is reasonably necessary for an active transaction, dispute, security investigation, backup recovery, fraud prevention, legal claim, or legal obligation. Records retained for an exception will be restricted to that purpose and removed or anonymized when the reason ends.

Published News may be archived rather than hard-deleted so HDC can preserve an accurate release and public-announcement history. Recognition-consent evidence may be retained with that history to demonstrate why a public name was displayed. If recognition consent is later withdrawn where withdrawal is legally applicable, HDC can remove the recognition from current public display while preserving restricted evidence necessary for accountability and prior publication history.

Expired security credentials stop working according to their technical expiry. HDC will maintain routine pruning for expired sessions, reset tokens, transient notifications, and diagnostic data. Encrypted backups follow the same purpose limitations and are removed through the backup rotation process.

If you request deletion, HDC will delete or de-identify data that is no longer necessary and explain any category that must temporarily be retained. Transaction records involving another participant and records required for security, disputes, legal compliance, or public-history integrity may be preserved in restricted or de-identified form where lawful.

9. SECURITY

HDC uses server-side password hashing, peppered recovery-answer hashing, signed and revocable sessions, role separation, participant authorization, PostgreSQL row-level security, restricted internal dashboards, encrypted transport, security headers, operation modes, audit records, immutable migration checksums, encrypted backup archives, and restore testing.

No internet service can guarantee absolute security. HDC will investigate suspected breaches, contain risk, preserve evidence, and provide notifications to affected people and the National Privacy Commission when required.

10. AUTOMATED PROCESSING

HDC uses rules to validate roles, calculate counts, detect conflicts, enforce quotas, assess prohibited message patterns, organize marketplace or transaction information, and control whether public recognition has sufficient recorded consent evidence. HDC does not currently make a decision producing legal or similarly significant effects solely through automated profiling. Material role, recovery, moderation, or dispute decisions requiring judgment are assigned to authorized human reviewers.

11. YOUR RIGHTS

Subject to the Data Privacy Act and lawful limitations, you may request to be informed; access your personal data; correct inaccurate data; object to certain processing; withdraw consent where consent is the basis; request erasure or blocking; obtain portable data in a commonly used electronic format; file a complaint with the National Privacy Commission; and seek damages where provided by law.

Submit a Privacy Request through Account Security and choose access, correction, objection, export, deletion, complaint, or another concern. HDC may ask for reasonable identity verification and clarification. HDC will acknowledge the request, restrict access where appropriate, and provide a decision or status without exposing another person's confidential information.

You may also contact the National Privacy Commission through https://privacy.gov.ph/ if you believe your rights were violated.

12. PUBLIC INFORMATION AND OTHER PEOPLE'S DATA

You control whether eligible role-profile fields are published. Public information and News can be viewed or copied by others, so do not publish private contact details unless you intend to share them. Supporter or sponsor recognition must use only the public display name and scope that the person or organization authorized.

You must have authority to submit another person's data and should provide only what is necessary for the transaction or permitted public recognition.

13. CHILDREN

HDC accounts and transactions are intended for adults who can enter contracts. A minor may use HDC only through a parent or legal guardian who provides the information and accepts responsibility. HDC should be notified if a child's data was submitted without proper authority so it can be reviewed and protected.

14. CHANGES AND ACCEPTANCE HISTORY

Material changes to this Notice receive a new version. Registered members must review and acknowledge the new version before protected account functions continue. HDC stores the document version, content integrity reference, source, and acceptance time. Prior versions remain part of the audit history and do not retroactively change earlier processing.

LEGAL REFERENCES

Data Privacy Act of 2012 (Republic Act No. 10173): https://privacy.gov.ph/data-privacy-act/
Implementing Rules and Regulations: https://privacy.gov.ph/implementing-rules-regulations-data-privacy-act-2012/
National Privacy Commission data-subject rights: https://privacy.gov.ph/data-subject-rights/
Internet Transactions Act of 2023 (Republic Act No. 11967): https://lawphil.net/statutes/repacts/ra2023/ra_11967_2023.html
'''
write('legal/terms-of-service-beta-2026-09-06.txt', terms)
write('legal/privacy-notice-beta-2026-09-06.txt', privacy)
terms_sha = hashlib.sha256(terms.encode()).hexdigest()
privacy_sha = hashlib.sha256(privacy.encode()).hexdigest()

legal_module = f'''export const CURRENT_LEGAL_VERSION = 'beta-2026-09-06';

export const CURRENT_LEGAL_DOCUMENTS = Object.freeze({{
  terms_of_service: Object.freeze({{
    documentType: 'terms_of_service',
    version: CURRENT_LEGAL_VERSION,
    title: 'HelpDesk Connect Beta Terms of Service',
    contentSha256: '{terms_sha}',
    publicPath: '/legal/terms/',
    effectiveAt: '2026-09-06T00:00:00.000Z',
  }}),
  privacy_notice: Object.freeze({{
    documentType: 'privacy_notice',
    version: CURRENT_LEGAL_VERSION,
    title: 'HelpDesk Connect Beta Privacy Notice',
    contentSha256: '{privacy_sha}',
    publicPath: '/legal/privacy/',
    effectiveAt: '2026-09-06T00:00:00.000Z',
  }}),
}});

export type LegalDocumentType = keyof typeof CURRENT_LEGAL_DOCUMENTS;

export function currentLegalDocumentList() {{
  return Object.values(CURRENT_LEGAL_DOCUMENTS).map((document) => ({{
    ...document,
  }}));
}}
'''
write('netlify/functions/_lib/legal-documents.mts', legal_module)

legal_dart = """const String hdcCurrentLegalVersion = 'beta-2026-09-06';

enum HDCLegalDocument { terms, privacy }

extension HDCLegalDocumentDetails on HDCLegalDocument {
  String get title => switch (this) {
    HDCLegalDocument.terms => 'HelpDesk Connect Beta Terms of Service',
    HDCLegalDocument.privacy => 'HelpDesk Connect Beta Privacy Notice',
  };

  String get shortTitle => switch (this) {
    HDCLegalDocument.terms => 'Terms of Service',
    HDCLegalDocument.privacy => 'Privacy Notice',
  };

  String get assetPath => switch (this) {
    HDCLegalDocument.terms => 'legal/terms-of-service-beta-2026-09-06.txt',
    HDCLegalDocument.privacy => 'legal/privacy-notice-beta-2026-09-06.txt',
  };

  String get publicPath => switch (this) {
    HDCLegalDocument.terms => '/legal/terms/',
    HDCLegalDocument.privacy => '/legal/privacy/',
  };
}
"""
write('lib/models/legal_document.dart', legal_dart)

pubspec = read('pubspec.yaml')
pubspec = pubspec.replace('legal/terms-of-service-beta-2026-08-29.txt', 'legal/terms-of-service-beta-2026-09-06.txt')
pubspec = pubspec.replace('legal/privacy-notice-beta-2026-08-29.txt', 'legal/privacy-notice-beta-2026-09-06.txt')
write('pubspec.yaml', pubspec)

prepare = read('scripts/prepare-netlify-web.mjs')
prepare = prepare.replace('terms-of-service-beta-2026-08-29.txt', 'terms-of-service-beta-2026-09-06.txt')
prepare = prepare.replace('privacy-notice-beta-2026-08-29.txt', 'privacy-notice-beta-2026-09-06.txt')
prepare = prepare.replace("version: 'beta-2026-08-29'", "version: 'beta-2026-09-06'")
write('scripts/prepare-netlify-web.mjs', prepare)

migration_0021 = f'''-- HDC Build 26: publish the material 6 September 2026 legal revision.
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_legal_documents') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0020'
     ) THEN
    RAISE EXCEPTION 'HDC migration 0020 must be applied first';
  END IF;
END
$$;

UPDATE public.hdc_legal_documents
SET status = 'superseded', superseded_at = COALESCE(superseded_at, now())
WHERE document_type IN ('terms_of_service', 'privacy_notice')
  AND document_version <> 'beta-2026-09-06'
  AND status = 'published';

INSERT INTO public.hdc_legal_documents (
  document_type, document_version, title, content_sha256, public_path,
  status, effective_at, superseded_at
) VALUES
  (
    'terms_of_service', 'beta-2026-09-06',
    'HelpDesk Connect Beta Terms of Service',
    '{terms_sha}', '/legal/terms/', 'published',
    '2026-09-06T00:00:00Z', NULL
  ),
  (
    'privacy_notice', 'beta-2026-09-06',
    'HelpDesk Connect Beta Privacy Notice',
    '{privacy_sha}', '/legal/privacy/', 'published',
    '2026-09-06T00:00:00Z', NULL
  )
ON CONFLICT (document_type, document_version) DO UPDATE SET
  title = EXCLUDED.title,
  content_sha256 = EXCLUDED.content_sha256,
  public_path = EXCLUDED.public_path,
  status = EXCLUDED.status,
  effective_at = EXCLUDED.effective_at,
  superseded_at = NULL;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0021', 'build26_legal_revision_2026_09_06', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
'''
write('migrations/0021_build26_legal_revision_2026_09_06.sql', migration_0021)

# ---------------------------------------------------------------------------
# Netlify builds Flutter from source. CI validates but never mutates PR heads.
# ---------------------------------------------------------------------------
netlify_build = r'''#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="$(tr -d '[:space:]' < .flutter-version)"
CACHE_ROOT="${HOME}/.cache/hdc-flutter"
FLUTTER_ROOT="${CACHE_ROOT}/flutter-${FLUTTER_VERSION}"
ARCHIVE="${CACHE_ROOT}/flutter-${FLUTTER_VERSION}.tar.xz"
mkdir -p "$CACHE_ROOT"

if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
  rm -rf "$FLUTTER_ROOT" "${CACHE_ROOT}/flutter"
  if [[ ! -f "$ARCHIVE" ]]; then
    curl --fail --location --retry 3 --retry-delay 2 \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      --output "$ARCHIVE"
  fi
  tar -xf "$ARCHIVE" -C "$CACHE_ROOT"
  mv "${CACHE_ROOT}/flutter" "$FLUTTER_ROOT"
fi

export PATH="${FLUTTER_ROOT}/bin:${PATH}"
git config --global --add safe.directory "$FLUTTER_ROOT" || true
flutter config --no-analytics >/dev/null
HDC_FLUTTER_BIN=flutter bash scripts/build-netlify-web.sh
'''
write('scripts/netlify-build.sh', netlify_build)

netlify = read('netlify.toml')
netlify = netlify.replace('[build]\n  publish = "build/web"', '[build]\n  command = "bash scripts/netlify-build.sh"\n  publish = "build/web"')
netlify = netlify.replace(
    '    X-Frame-Options = "DENY"',
    '    X-Frame-Options = "DENY"\n    Strict-Transport-Security = "max-age=31536000; includeSubDomains"',
)
write('netlify.toml', netlify)

ci = read('.github/workflows/ci.yml')
# Add stable concurrency and remove write permission / bundle synchronization.
ci = ci.replace(
    "permissions:\n  contents: read\n",
    "permissions:\n  contents: read\n\nconcurrency:\n  group: hdc-ci-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}\n  cancel-in-progress: true\n",
    1,
)
ci = ci.replace(
    "      - name: Secret-pattern sanity scan",
    "      - name: Production dependency audit\n        run: npm audit --omit=dev --audit-level=high\n\n      - name: Secret-pattern sanity scan",
    1,
)
ci = ci.replace("    permissions:\n      contents: write\n", '')
ci = ci.replace(
    "      - name: Upload verified Flutter web bundle\n        uses: actions/upload-artifact@v4\n        with:\n          name: hdc-web-build25",
    "      - name: Read release artifact name\n        id: release-artifact\n        shell: bash\n        run: |\n          set -euo pipefail\n          build_number=\"$(node -p \"require('./package.json').version.match(/build\\.(\\d+)$/)[1]\")\"\n          echo \"name=hdc-web-build${build_number}\" >> \"$GITHUB_OUTPUT\"\n\n      - name: Upload verified Flutter web bundle\n        uses: actions/upload-artifact@v4\n        with:\n          name: ${{ steps.release-artifact.outputs.name }}",
    1,
)
ci = re.sub(
    r"\n      - name: Synchronize verified web bundle with review branch.*?git push origin \"HEAD:\$\{HDC_REVIEW_BRANCH\}\"\n",
    '\n',
    ci,
    count=1,
    flags=re.S,
)
write('.github/workflows/ci.yml', ci)

release_check = r'''import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const read = (path) => readFile(new URL(path, root), 'utf8');

const packageJson = JSON.parse(await read('package.json'));
const release = /^(\d+\.\d+\.\d+)-build\.(\d+)$/.exec(packageJson.version);
assert.ok(release, 'package.json must use x.y.z-build.N');
const [, semanticVersion, buildNumber] = release;

const expected = {
  flutter: `version: ${semanticVersion}+${buildNumber}`,
  app: `${semanticVersion} Beta (Build ${buildNumber})`,
  footer: `HelpDesk Connect Beta v${semanticVersion} Build ${buildNumber}`,
  health: `${semanticVersion}-build${buildNumber}`,
  startup: `Build ${buildNumber}`,
};
const files = {
  flutter: await read('pubspec.yaml'),
  app: await read('lib/core/config/app_config.dart'),
  footer: await read('lib/features/dashboard/dashboard_screen.dart'),
  health: await read('netlify/functions/api.mts'),
  startup: await read('web/index.html'),
};
for (const [target, marker] of Object.entries(expected)) {
  assert.ok(files[target].includes(marker), `${target} release marker is not synchronized: expected ${marker}`);
}

const ci = await read('.github/workflows/ci.yml');
assert.ok(!ci.includes('git push origin'), 'CI must validate source without mutating review branches');
const netlify = await read('netlify.toml');
assert.ok(netlify.includes('command = "bash scripts/netlify-build.sh"'), 'Netlify must build Flutter web from source');

console.log(`HDC release markers synchronized at ${semanticVersion}+${buildNumber}.`);
'''
write('scripts/check-release-sync.mjs', release_check)

# build/web is no longer source-controlled; Netlify and CI generate it.
shutil.rmtree(ROOT / 'build' / 'web', ignore_errors=True)
gitignore = read('.gitignore')
gitignore = gitignore.replace('/build/*\n!/build/web/\n!/build/web/**', '/build/')
write('.gitignore', gitignore)

# ---------------------------------------------------------------------------
# Dependency monitoring and release-policy documentation.
# ---------------------------------------------------------------------------
dependabot = '''version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly
    open-pull-requests-limit: 5
  - package-ecosystem: pub
    directory: /
    schedule:
      interval: weekly
    open-pull-requests-limit: 5
'''
write('.github/dependabot.yml', dependabot)
write('.github/CODEOWNERS', '* @cyriltagalog123-a11y\n')

release_policy = '''# HDC repository release policy

HDC production changes use a review branch and pull request. The release branch must pass HDC CI, Flutter analyze/tests/build, PostgreSQL workflow/isolation tests, migration checksum verification, dependency audit, and encrypted backup/restore rehearsal before merge.

The connected repository automation used by the HDC owner must retain enough access to create branches, update review branches, open pull requests, merge approved releases, and create rollback branches. Do not enable a GitHub protection rule that blocks that owner-authorized release path unless an explicit bypass for the owner/authorized automation has first been verified.

CI is read-only with respect to repository contents. It must never push generated Flutter bundles back into pull-request branches. Netlify builds the pinned Flutter web bundle from source on deploy.

Production merges require a pre-deploy rollback branch. Force-pushing or deleting `main` is prohibited by HDC release policy even when repository-host settings cannot enforce that rule through the connected automation.
'''
write('docs/REPOSITORY_RELEASE_POLICY.md', release_policy)

# ---------------------------------------------------------------------------
# Legal/current release docs and archive old root build notes.
# ---------------------------------------------------------------------------
archive = ROOT / 'docs' / 'archive' / 'builds'
archive.mkdir(parents=True, exist_ok=True)
for old in ROOT.glob('README_BUILD_*.txt'):
    shutil.move(str(old), str(archive / old.name))
legacy_changelog = ROOT / 'CHANGELOG.txt'
if legacy_changelog.exists():
    shutil.move(str(legacy_changelog), str(ROOT / 'docs' / 'archive' / 'CHANGELOG-legacy.txt'))

# Remove clearly obsolete unreachable prototype surfaces. Git history remains the archive.
for obsolete in [
    'lib/features/booking',
    'lib/features/brand',
    'lib/features/department',
    'lib/features/employee',
    'lib/features/assets',
    'lib/routes',
]:
    shutil.rmtree(ROOT / obsolete, ignore_errors=True)

changelog = read('CHANGELOG.md')
entry = '''# HDC Change Log

## 0.6.4+26 — Build 26 — 2026-09-06

- Consolidates public registration on `/api/auth/register` with the controlled-location contract; `/api/auth/register-v2` remains a deprecated compatibility alias for older Build 25 clients.
- Applies operation-mode enforcement to account creation, equalizes login password-hash work for unknown accounts, and caps JSON request bodies at 64 KiB by default.
- Adds latest-schema readiness checks through migration 0021 and shared internal-role authorization for privileged standalone functions.
- Strengthens public News history and supporter-recognition evidence with consent time, method, approved scope, optional internal reference, and an immutable-after-publication lifecycle.
- Publishes the material 6 September 2026 Terms and Privacy revision covering public News, supporter recognition, SaiCore support identity, future PHP support channels, and owner contact.
- Reworks release delivery so CI is read-only and Netlify builds the pinned Flutter web bundle from source; generated `build/web` output is no longer committed to review branches.
- Adds production dependency auditing, Dependabot configuration, CI concurrency, HSTS, CODEOWNERS, and a release-policy document that preserves the owner-authorized build path.
- Hides unfinished HDC Passport navigation, removes obsolete prototype screens/routes, archives old root build notes, and updates release documentation.
- Moves Knowledge Base implementation to Build 27; the current Knowledge Base remains an explicit non-fabricating Build 27 shell.

## Post-Build-25 support/news foundation — 2026-09-06

- Adds public HDC News with Owner/Super Admin/Admin authoring, support/recognition consent gating, SaiCore Support HDC and Contact Owner pages, and the Knowledge Base placeholder now assigned to Build 27.

'''
if changelog.startswith('# HDC Change Log\n'):
    changelog = entry + changelog[len('# HDC Change Log\n\n'):]
else:
    changelog = entry + changelog
write('CHANGELOG.md', changelog)

readme = read('README.md')
insert = '''\n## Build 26 hardening baseline\n\nBuild 26 is the pre-Knowledge-Base security and maintainability baseline. Public registration is canonical at `POST /api/auth/register` and requires the controlled HDC location contract. `POST /api/auth/register-v2` is retained only as a deprecated compatibility alias for older clients. CI no longer modifies pull-request branches; Netlify builds the pinned Flutter bundle directly from reviewed source. Public News preserves published history and stores structured recognition-consent evidence. The current legal version is `beta-2026-09-06`. Knowledge Base implementation is deferred to Build 27.\n\nCurrent public/support endpoints also include `GET /api/news` and the owner-authorized `GET|POST|PUT|DELETE /api/internal/news` management function. Public platform-role administration remains separately server-authorized.\n'''
readme = readme.replace('\n## Endpoints\n', insert + '\n## Endpoints\n', 1)
readme = readme.replace('- `POST /api/auth/register`', '- `POST /api/auth/register` (canonical controlled-location registration)\n- `POST /api/auth/register-v2` (deprecated Build 25 compatibility alias)')
readme = readme.replace('- `GET /api/internal/dashboard`', '- `GET /api/news` (public published News)\n- `GET|POST|PUT|DELETE /api/internal/news` (Owner/Super Admin/Admin only)\n- `GET /api/internal/dashboard`')
write('README.md', readme)

# ---------------------------------------------------------------------------
# Build 26 regression contract.
# ---------------------------------------------------------------------------
build26_test = r'''import { describe, expect, it } from 'vitest';
import { readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const read = (path: string) => readFile(new URL(path, root), 'utf8');

describe('Build 26 hardening contract', () => {
  it('uses one permanent controlled-location registration contract', async () => {
    const gateway = await read('lib/core/auth/hdc_api_auth_gateway.dart');
    const registration = await read('netlify/functions/_lib/registration.mts');
    const alias = await read('netlify/functions/register-v2.mts');
    expect(gateway).toContain("'/api/auth/register'");
    expect(registration).toContain('normalizeHdcLocation');
    expect(registration).toContain("operationMode() !== 'normal'");
    expect(alias).toContain("deprecation', 'true'");
    expect(alias).toContain('</api/auth/register>');
  });

  it('keeps CI read-only and Netlify responsible for source-built Flutter web', async () => {
    const ci = await read('.github/workflows/ci.yml');
    const netlify = await read('netlify.toml');
    expect(ci).not.toContain('git push origin');
    expect(ci).not.toContain('contents: write');
    expect(ci).toContain('npm audit --omit=dev --audit-level=high');
    expect(netlify).toContain('bash scripts/netlify-build.sh');
  });

  it('retains published News and requires richer recognition consent evidence', async () => {
    const migration = await read('migrations/0020_build26_news_consent_history.sql');
    const admin = await read('netlify/functions/news-admin.mts');
    expect(migration).toContain('ever_published');
    expect(migration).toContain('recognition_consent_method');
    expect(migration).toContain('Published HDC news history must be archived and retained');
    expect(admin).toContain('recognitionConsentScope');
    expect(admin).toContain('ever_published = false');
  });

  it('moves real Knowledge Base implementation to Build 27', async () => {
    const kb = await read('lib/features/knowledge_base/knowledge_base_screen.dart');
    expect(kb).toContain('BUILD 27 READY');
    expect(kb).toContain('implemented in Build 27');
    expect(kb).not.toContain('Search becomes active in Build 26');
  });

  it('publishes the current legal revision and latest-schema readiness', async () => {
    const legal = await read('netlify/functions/_lib/legal-documents.mts');
    const api = await read('netlify/functions/api.mts');
    expect(legal).toContain("CURRENT_LEGAL_VERSION = 'beta-2026-09-06'");
    expect(api).toContain("version = '0021'");
    expect(api).toContain("build: '0.6.4-build26'");
  });
});
'''
write('tests/build26-hardening.test.ts', build26_test)

# Update release-dependent expectations in active tests without rewriting historical prose.
for base in [ROOT / 'tests', ROOT / 'test']:
    if not base.exists():
        continue
    for path in base.rglob('*'):
        if path.suffix not in {'.ts', '.dart'}:
            continue
        text = path.read_text(encoding='utf-8')
        text = text.replace('0.6.4-build25', '0.6.4-build26')
        text = text.replace('0.6.4-build.25', '0.6.4-build.26')
        text = text.replace('0.6.4+25', '0.6.4+26')
        text = text.replace('beta-2026-08-29', 'beta-2026-09-06')
        text = text.replace('legal/terms-of-service-beta-2026-08-29.txt', 'legal/terms-of-service-beta-2026-09-06.txt')
        text = text.replace('legal/privacy-notice-beta-2026-08-29.txt', 'legal/privacy-notice-beta-2026-09-06.txt')
        path.write_text(text, encoding='utf-8')

# Migration checksums are immutable for 0000-0019 and appended for Build 26.
checksums = json.loads(read('migrations/checksums.json'))
for filename in [
    '0020_build26_news_consent_history.sql',
    '0021_build26_legal_revision_2026_09_06.sql',
]:
    checksums['files'][filename] = hashlib.sha256((ROOT / 'migrations' / filename).read_bytes()).hexdigest()
write('migrations/checksums.json', json.dumps(checksums, indent=2) + '\n')

print('Build 26 hardening patch applied.')
