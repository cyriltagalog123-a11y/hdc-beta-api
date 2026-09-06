import bcrypt from 'bcryptjs';
import { openDb, closeDb } from './_lib/db.mjs';
import { corsPreflightResponse, withCors } from './_lib/cors.mjs';
import { json, methodNotAllowed, readJson } from './_lib/http.mjs';
import { normalizeDisplayName, normalizeEmail, normalizePassword } from './_lib/validation.mjs';
import {
  RECOVERY_QUESTION_VERSION,
  normalizeRecoveryAnswer,
  parseRecoveryAnswers,
  recoveryAnswerDigest,
} from './_lib/account-recovery.mjs';
import { currentRecoveryPepper } from './_lib/env.mjs';
import { CURRENT_LEGAL_DOCUMENTS, CURRENT_LEGAL_VERSION } from './_lib/legal-documents.mjs';
import { normalizeHdcLocation } from './_lib/locations.mjs';

async function handleRegister(req: Request): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
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

  const sql = openDb();
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
            'registration', ${tx.json({ source: 'registration_v2' })}
          ),
          (
            ${userId}, 'privacy_notice', ${termsVersion},
            ${CURRENT_LEGAL_DOCUMENTS.privacy_notice.contentSha256},
            'registration', ${tx.json({ source: 'registration_v2' })}
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
          ${tx.json({ source: 'public_registration_v2', location })}
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
    console.error('Registration v2 failed', error instanceof Error ? error.message : 'unknown_error');
    return json({ error: 'registration_failed' }, 500);
  } finally {
    await closeDb(sql);
  }
}

export default async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return corsPreflightResponse(req);
  return withCors(req, await handleRegister(req));
};

export const config = {
  path: '/api/auth/register-v2',
};
