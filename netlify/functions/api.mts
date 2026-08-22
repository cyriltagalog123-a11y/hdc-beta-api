import type { Config, Context } from '@netlify/functions';
import bcrypt from 'bcryptjs';
import { createHmac, randomBytes, randomUUID } from 'node:crypto';
import type { DbClient } from './_lib/db.mjs';
import { closeDb, openDb } from './_lib/db.mjs';
import { bearerToken, json, methodNotAllowed, readJson } from './_lib/http.mjs';
import { securityReviewEmail, sessionSecret } from './_lib/env.mjs';
import { signSessionToken, verifySessionToken } from './_lib/session.mjs';
import { normalizeDisplayName, normalizeEmail, normalizePassword } from './_lib/validation.mjs';
import {
  RECOVERY_QUESTION_VERSION,
  normalizeRecoveryAnswer,
  parseRecoveryAnswers,
  passwordResetTokenHash,
  publicRecoveryQuestions,
  recoveryAnswerDigest,
} from './_lib/account-recovery.mjs';
import {
  normalizeMemberProfileWrite,
  normalizePlatformRoleProfileWrite,
} from './_lib/profiles.mjs';
import { internalDashboardPermissions } from './_lib/internal-dashboard.mjs';
import {
  canApprovePlatformRoles,
  isApprovalPlatformRoleCode,
  isPlatformRoleCode,
  normalizeRoleApplicationNote,
  normalizeRoleCode,
  splitRoleCodes,
  type ApprovalPlatformRoleCode,
  type InternalRoleCode,
  type PlatformRoleCode,
} from './_lib/roles.mjs';
import {
  ROLE_APPLICATION_FORM_VERSION,
  normalizeRoleApplicationAnswers,
} from './_lib/role-applications.mjs';
import {
  WorkflowHttpError,
  canCustomerUpdateProposalStatus,
  canCustomerUpdateRequestStatus,
  canTechnicianUpdateProposalStatus,
  newWorkflowId,
  parseProposalWrite,
  parseServiceRequestWrite,
  proposalQualityScore,
  proposalView,
  serviceRequestView,
  serviceTransactionView,
  technicianReputation,
  transactionSeedView,
  transactionTransition,
  type WorkflowUser,
} from './_lib/workflow.mjs';

const SESSION_DAYS = 7;
const LOGIN_FAILURE_LIMIT = 5;
const LOGIN_FAILURE_WINDOW_MINUTES = 15;
const RECOVERY_FAILURE_LIMIT = 5;
const RECOVERY_FAILURE_WINDOW_MINUTES = 60;
const RESET_TOKEN_MINUTES = 15;
const CURRENT_TERMS_VERSION = 'beta-2026-08';
const DUMMY_RECOVERY_HASH =
  '$2b$12$ibDq6pxirBndt2VuaSnxnOW9kJGgAFQE3ZTpEfOxq3uszeDT982z6';

type UserView = {
  id: string;
  publicMemberId: string;
  email: string;
  displayName: string;
  status: string;
  emailVerified: boolean;
  /** @deprecated Use platformRoles. Retained for one client transition. */
  roles: string[];
  platformRoles: PlatformRoleCode[];
  internalRoles: InternalRoleCode[];
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
  metadata: Record<string, string | number | boolean | null> = {},
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
    SELECT id, public_member_id, email::text AS email, display_name, status, email_verified,
           created_at, updated_at
    FROM public.hdc_users
    WHERE id = ${userId}
    LIMIT 1
  `;
  if (users.length === 0) return null;

  const roleRows = await sql`
    SELECT role
    FROM public.hdc_user_roles
    WHERE user_id = ${userId} AND is_active = true
    ORDER BY role
  `;

  // During rollout, legacy admin/super_admin rows may still live in
  // hdc_user_roles. Split them defensively so they never become platform
  // capability claims. Migration 0003 moves them to the private table.
  const splitLegacyRoles = splitRoleCodes(
    roleRows.map((row) => String(row.role)),
  );
  const internalRoles = new Set<InternalRoleCode>(splitLegacyRoles.internalRoles);

  const internalTable = await sql`
    SELECT to_regclass('public.hdc_internal_role_assignments')::text AS relation
  `;
  if (internalTable[0]?.relation) {
    const internalRoleRows = await sql`
      SELECT role
      FROM public.hdc_internal_role_assignments
      WHERE user_id = ${userId} AND is_active = true
      ORDER BY role
    `;
    const splitInternalRoles = splitRoleCodes(
      internalRoleRows.map((row) => String(row.role)),
    );
    for (const role of splitInternalRoles.internalRoles) internalRoles.add(role);
  }

  const user = users[0];
  const platformRoles = [...splitLegacyRoles.platformRoles].sort();
  return {
    id: String(user.id),
    publicMemberId: String(user.public_member_id),
    email: String(user.email),
    displayName: String(user.display_name),
    status: String(user.status),
    emailVerified: Boolean(user.email_verified),
    roles: [...platformRoles],
    platformRoles,
    internalRoles: [...internalRoles].sort(),
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
  const recoveryAnswers = parseRecoveryAnswers(body.recoveryAnswers);
  const termsAccepted = body.termsAccepted === true;
  const termsVersion = typeof body.termsVersion === 'string'
    ? body.termsVersion.trim()
    : '';
  if (
    !email || !displayName || !password || !recoveryAnswers ||
    !termsAccepted || termsVersion !== CURRENT_TERMS_VERSION
  ) {
    return json({
      error: 'invalid_registration',
      message: 'Complete the account details, all three recovery questions, and the terms acceptance.',
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
  const pepper = sessionSecret();
  const recoveryHashes = await Promise.all(recoveryAnswers.map(async (item) => ({
    questionCode: item.questionCode,
    answerHash: await bcrypt.hash(
      recoveryAnswerDigest(item.answer, pepper),
      12,
    ),
  })));

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
      for (const item of recoveryHashes) {
        await tx`
          INSERT INTO public.hdc_account_recovery_answers (
            user_id, question_version, question_code, answer_hash
          ) VALUES (
            ${userId}, ${RECOVERY_QUESTION_VERSION},
            ${item.questionCode}, ${item.answerHash}
          )
        `;
      }
      await tx`
        INSERT INTO public.hdc_terms_acceptances (
          user_id, document_type, document_version, client_metadata
        ) VALUES
          (${userId}, 'terms_of_service', ${termsVersion}, ${tx.json({ source: 'registration' })}),
          (${userId}, 'privacy_notice', ${termsVersion}, ${tx.json({ source: 'registration' })})
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

async function handleRecoveryStart(req: Request): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body || !normalizeEmail(body.email)) {
    return json({
      error: 'invalid_recovery_request',
      message: 'Enter a valid email address.',
    }, 400);
  }

  // Questions are fixed for this version, so the response never confirms
  // whether the supplied email belongs to an HDC account.
  return json({
    questionVersion: RECOVERY_QUESTION_VERSION,
    questions: publicRecoveryQuestions(),
  });
}

async function recentRecoveryFailures(
  sql: DbClient,
  fingerprint: string,
): Promise<number> {
  const rows = await sql`
    SELECT count(*)::int AS failures
    FROM public.hdc_security_audit
    WHERE event_type = 'auth.recovery.verify'
      AND event_status IN ('failed', 'blocked')
      AND metadata->>'identity_fingerprint' = ${fingerprint}
      AND created_at > now() -
        (${RECOVERY_FAILURE_WINDOW_MINUTES} * interval '1 minute')
  `;
  return Number(rows[0]?.failures ?? 0);
}

function newResetCredential(): {
  token: string;
  tokenHash: string;
  expiresAt: Date;
} {
  const token = randomBytes(32).toString('base64url');
  return {
    token,
    tokenHash: passwordResetTokenHash(token),
    expiresAt: new Date(Date.now() + RESET_TOKEN_MINUTES * 60 * 1000),
  };
}

async function queueManualRecoveryReview(
  sql: DbClient,
  user: UserView,
  fingerprint: string,
): Promise<void> {
  const configuredReviewEmail = normalizeEmail(securityReviewEmail());
  await sql.begin(async (tx) => {
    const requestRows = await tx`
      INSERT INTO public.hdc_account_recovery_review_requests (
        user_id,
        identity_fingerprint,
        delivery_status,
        review_email_snapshot
      ) VALUES (
        ${user.id},
        ${fingerprint},
        ${configuredReviewEmail ? 'queued' : 'pending_configuration'},
        ${configuredReviewEmail}
      )
      ON CONFLICT (user_id) WHERE status = 'pending'
      DO UPDATE SET
        identity_fingerprint = EXCLUDED.identity_fingerprint,
        review_email_snapshot = EXCLUDED.review_email_snapshot,
        delivery_status = CASE
          WHEN public.hdc_account_recovery_review_requests.delivery_status = 'sent'
            THEN 'sent'
          ELSE EXCLUDED.delivery_status
        END,
        updated_at = now()
      RETURNING id, (xmax = 0) AS was_inserted
    `;
    const requestId = String(requestRows[0].id);
    const wasInserted = requestRows[0].was_inserted === true;

    if (wasInserted) {
      await tx`
        INSERT INTO public.hdc_notifications (
          user_id, event_type, priority, title, message, metadata
        )
        SELECT
          assignment.user_id,
          'security.recovery_review_requested',
          'critical',
          'Manual account recovery review',
          ${`A manual password recovery review was requested for ${user.publicMemberId}.`},
          ${tx.json({
            recoveryRequestId: requestId,
            applicantUserId: user.id,
            publicMemberId: user.publicMemberId,
          })}
        FROM public.hdc_internal_role_assignments assignment
        WHERE assignment.is_active = true
          AND assignment.role IN ('owner', 'super_admin')
      `;
    }

    if (wasInserted && configuredReviewEmail) {
      await tx`
        INSERT INTO public.hdc_security_delivery_outbox (
          purpose, recipient, subject, body_text, metadata
        ) VALUES (
          'manual_recovery_review',
          ${configuredReviewEmail},
          'HDC manual account recovery review',
          ${`A manual recovery request for ${user.publicMemberId} is waiting in the private HDC dashboard.`},
          ${tx.json({
            recoveryRequestId: requestId,
            publicMemberId: user.publicMemberId,
          })}
        )
      `;
    }
  });
}

async function handleRecoveryVerify(
  req: Request,
  sql: DbClient,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const email = normalizeEmail(body.email);
  const answers = parseRecoveryAnswers(body.answers);
  if (!email || !answers) {
    return json({
      error: 'invalid_recovery_answers',
      message: 'Complete all three recovery questions.',
    }, 400);
  }

  const fingerprint = identityFingerprint(email);
  if (await recentRecoveryFailures(sql, fingerprint) >= RECOVERY_FAILURE_LIMIT) {
    await audit(sql, null, 'auth.recovery.verify', 'blocked', {
      reason: 'rate_limit',
      identity_fingerprint: fingerprint,
    });
    return json({
      error: 'too_many_attempts',
      message: 'Recovery attempts are temporarily limited. Try again later.',
    }, 429);
  }

  const userRows = await sql`
    SELECT id
    FROM public.hdc_users
    WHERE email = ${email} AND status = 'active'
    LIMIT 1
  `;
  const userId = userRows.length > 0 ? String(userRows[0].id) : null;
  const answerRows = userId
    ? await sql`
        SELECT question_code, answer_hash
        FROM public.hdc_account_recovery_answers
        WHERE user_id = ${userId}
          AND question_version = ${RECOVERY_QUESTION_VERSION}
      `
    : [];
  const storedHashes = new Map(
    answerRows.map((row) => [String(row.question_code), String(row.answer_hash)]),
  );
  const pepper = sessionSecret();
  const comparisons = await Promise.all(answers.map(async (item) => {
    const storedHash = storedHashes.get(item.questionCode);
    const valid = await bcrypt.compare(
      recoveryAnswerDigest(item.answer, pepper),
      storedHash ?? DUMMY_RECOVERY_HASH,
    );
    return Boolean(storedHash) && valid;
  }));
  const correctCount = comparisons.filter(Boolean).length;

  if (userId && correctCount >= 2) {
    const credential = newResetCredential();
    await sql.begin(async (tx) => {
      await tx`
        UPDATE public.hdc_password_reset_tokens
        SET status = 'revoked', consumed_at = COALESCE(consumed_at, now())
        WHERE user_id = ${userId} AND status = 'pending'
      `;
      await tx`
        INSERT INTO public.hdc_password_reset_tokens (
          user_id, token_digest, source, expires_at
        ) VALUES (
          ${userId}, ${credential.tokenHash}, 'security_questions',
          ${credential.expiresAt}
        )
      `;
      await tx`
        UPDATE public.hdc_account_recovery_review_requests
        SET status = 'cancelled', delivery_status = 'not_required'
        WHERE user_id = ${userId} AND status = 'pending'
      `;
    });
    await audit(sql, userId, 'auth.recovery.verify', 'success', {
      identity_fingerprint: fingerprint,
      method: 'security_questions',
    });
    return json({
      result: 'verified',
      resetToken: credential.token,
      expiresAt: credential.expiresAt.toISOString(),
    });
  }

  if (userId) {
    const user = await getUserView(sql, userId);
    if (user) await queueManualRecoveryReview(sql, user, fingerprint);
  }
  await audit(sql, userId, 'auth.recovery.verify', 'failed', {
    identity_fingerprint: fingerprint,
    result: 'manual_review',
  });
  return json({ result: 'manual_review_submitted' }, 202);
}

async function handlePasswordReset(
  req: Request,
  sql: DbClient,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const rawToken = body.resetToken ?? body.token;
  const token = typeof rawToken === 'string'
    ? rawToken.trim()
    : '';
  const password = normalizePassword(body.newPassword ?? body.password);
  if (token.length < 32 || token.length > 200 || !password) {
    return json({
      error: 'invalid_password_reset',
      message: 'Use a valid reset link and a password of 12-128 characters.',
    }, 400);
  }

  const tokenHash = passwordResetTokenHash(token);
  const passwordHash = await bcrypt.hash(password, 12);
  try {
    const userId = await sql.begin(async (tx) => {
      const tokenRows = await tx`
        SELECT reset.id, reset.user_id
        FROM public.hdc_password_reset_tokens reset
        JOIN public.hdc_users member ON member.id = reset.user_id
        WHERE reset.token_digest = ${tokenHash}
          AND reset.status = 'pending'
          AND reset.consumed_at IS NULL
          AND reset.expires_at > now()
          AND member.status = 'active'
        FOR UPDATE OF reset
      `;
      if (tokenRows.length === 0) {
        throw new WorkflowHttpError(
          'reset_link_invalid',
          410,
          'This reset link is invalid, expired, or already used.',
        );
      }
      const resetId = String(tokenRows[0].id);
      const resetUserId = String(tokenRows[0].user_id);
      await tx`
        UPDATE public.hdc_users
        SET password_hash = ${passwordHash}, updated_at = now()
        WHERE id = ${resetUserId}
      `;
      await tx`
        UPDATE public.hdc_password_reset_tokens
        SET status = 'consumed', consumed_at = now()
        WHERE id = ${resetId}
      `;
      await tx`
        UPDATE public.hdc_password_reset_tokens
        SET status = 'revoked', consumed_at = COALESCE(consumed_at, now())
        WHERE user_id = ${resetUserId}
          AND id <> ${resetId}
          AND status = 'pending'
      `;
      await tx`
        UPDATE public.hdc_auth_sessions
        SET revoked_at = now()
        WHERE user_id = ${resetUserId} AND revoked_at IS NULL
      `;
      return resetUserId;
    });
    await audit(sql, userId, 'auth.password_reset', 'success', {
      sessions_revoked: true,
    });
    return json({ success: true });
  } catch (error) {
    if (error instanceof WorkflowHttpError) {
      return json({ error: error.code, message: error.message }, error.statusCode);
    }
    throw error;
  }
}

function recoveryReviewView(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: String(row.id),
    userId: String(row.user_id),
    publicMemberId: String(row.public_member_id),
    displayName: String(row.display_name),
    email: String(row.email),
    status: String(row.status),
    deliveryStatus: String(row.delivery_status),
    reviewerNote: String(row.reviewer_note ?? ''),
    reviewedBy: row.reviewed_by ? String(row.reviewed_by) : null,
    reviewedAt: row.reviewed_at
      ? new Date(String(row.reviewed_at)).toISOString()
      : null,
    createdAt: new Date(String(row.created_at)).toISOString(),
    updatedAt: new Date(String(row.updated_at)).toISOString(),
  };
}

async function handleListRecoveryReviews(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  await requireAccountRecoveryReviewer(sql, user);
  const rows = await sql`
    SELECT
      review.*,
      member.public_member_id,
      member.display_name,
      member.email::text AS email
    FROM public.hdc_account_recovery_review_requests review
    JOIN public.hdc_users member ON member.id = review.user_id
    WHERE review.status = 'pending'
    ORDER BY review.created_at ASC
    LIMIT 200
  `;
  return json({
    requests: rows.map((row) => recoveryReviewView(rowObject(row))),
  });
}

async function handleReviewRecoveryRequest(
  req: Request,
  sql: DbClient,
  reviewer: UserView,
  requestId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  await requireAccountRecoveryReviewer(sql, reviewer);
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const decision = normalizeRoleCode(body.decision);
  if (decision !== 'approved' && decision !== 'rejected') {
    return json({ error: 'invalid_recovery_decision' }, 400);
  }
  const note = normalizeRoleApplicationNote(body.note);
  if (note === null || (decision === 'rejected' && note.length === 0)) {
    return json({
      error: 'invalid_review_note',
      message: 'A rejection requires a private review note.',
    }, 400);
  }

  const credential = decision === 'approved' ? newResetCredential() : null;
  const reviewed = await sql.begin(async (tx) => {
    const currentRows = await tx`
      SELECT review.*, member.public_member_id, member.display_name,
             member.email::text AS email
      FROM public.hdc_account_recovery_review_requests review
      JOIN public.hdc_users member ON member.id = review.user_id
      WHERE review.id = ${requestId}
      FOR UPDATE OF review
    `;
    if (currentRows.length === 0) {
      throw new WorkflowHttpError(
        'recovery_review_not_found', 404, 'The recovery review was not found.',
      );
    }
    const current = rowObject(currentRows[0]);
    if (String(current.status) !== 'pending') {
      throw new WorkflowHttpError(
        'recovery_review_already_completed',
        409,
        'The recovery review has already been completed.',
      );
    }
    const applicantUserId = String(current.user_id);

    if (credential) {
      await tx`
        UPDATE public.hdc_password_reset_tokens
        SET status = 'revoked', consumed_at = COALESCE(consumed_at, now())
        WHERE user_id = ${applicantUserId} AND status = 'pending'
      `;
      await tx`
        INSERT INTO public.hdc_password_reset_tokens (
          user_id, token_digest, source, expires_at
        ) VALUES (
          ${applicantUserId}, ${credential.tokenHash}, 'manual_review',
          ${credential.expiresAt}
        )
      `;
    }

    const updatedRows = await tx`
      UPDATE public.hdc_account_recovery_review_requests
      SET
        status = ${decision},
        delivery_status = 'not_required',
        reviewer_note = ${note},
        reviewed_by = ${reviewer.id},
        reviewed_at = now()
      WHERE id = ${requestId}
      RETURNING *
    `;
    await tx`
      INSERT INTO public.hdc_notifications (
        user_id, event_type, priority, title, message, metadata
      ) VALUES (
        ${applicantUserId},
        ${decision === 'approved'
          ? 'security.recovery_review_approved'
          : 'security.recovery_review_rejected'},
        'critical',
        'Account recovery review',
        ${decision === 'approved'
          ? 'Your manual account recovery review was approved.'
          : 'Your manual account recovery review needs further confirmation.'},
        ${tx.json({ recoveryRequestId: requestId, decision })}
      )
    `;
    return {
      ...rowObject(updatedRows[0]),
      public_member_id: current.public_member_id,
      display_name: current.display_name,
      email: current.email,
    };
  });

  await audit(sql, reviewer.id, 'auth.recovery.review', 'success', {
    recovery_request_id: requestId,
    decision,
  });
  return json({
    request: recoveryReviewView(reviewed),
    ...(credential
      ? {
          resetToken: credential.token,
          expiresAt: credential.expiresAt.toISOString(),
          manualDeliveryRequired: true,
        }
      : {}),
  });
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

function workflowUser(user: UserView): WorkflowUser {
  return {
    id: user.id,
    displayName: user.displayName,
    roles: [...user.platformRoles],
    createdAt: user.createdAt,
  };
}

function requireWorkflowRole(user: UserView, role: string): void {
  if (!user.platformRoles.includes(role as PlatformRoleCode)) {
    throw new WorkflowHttpError(
      'forbidden',
      403,
      `The ${role} role is required for this action.`,
    );
  }
}

function requirePathId(value: string): string {
  if (!/^[A-Za-z0-9._:-]{3,100}$/.test(value)) {
    throw new WorkflowHttpError('invalid_identifier', 400, 'The workflow identifier is invalid.');
  }
  return value;
}

type PlatformRoleReviewScope = {
  allRoles: boolean;
  roles: Set<ApprovalPlatformRoleCode>;
};

async function platformRoleReviewScope(
  sql: DbClient,
  user: UserView,
): Promise<PlatformRoleReviewScope> {
  if (canApprovePlatformRoles(user.internalRoles)) {
    return { allRoles: true, roles: new Set() };
  }
  if (user.internalRoles.length === 0) {
    return { allRoles: false, roles: new Set() };
  }
  const rows = await sql`
    SELECT role_scope
    FROM public.hdc_internal_permission_grants
    WHERE user_id = ${user.id}
      AND permission_code = 'platform_roles.review'
      AND is_active = true
  `;
  if (rows.some((row) => row.role_scope === null)) {
    return { allRoles: true, roles: new Set() };
  }
  const roles = new Set<ApprovalPlatformRoleCode>();
  for (const row of rows) {
    const role = normalizeRoleCode(row.role_scope);
    if (role && isApprovalPlatformRoleCode(role)) roles.add(role);
  }
  return { allRoles: false, roles };
}

async function requirePlatformRoleApprover(
  sql: DbClient,
  user: UserView,
  role?: ApprovalPlatformRoleCode,
): Promise<PlatformRoleReviewScope> {
  const scope = await platformRoleReviewScope(sql, user);
  if (!scope.allRoles && (role === undefined || !scope.roles.has(role))) {
    if (role === undefined && scope.roles.size > 0) return scope;
    throw new WorkflowHttpError(
      'internal_role_required',
      403,
      'Private approval permission is required for this action.',
    );
  }
  return scope;
}

async function requireAccountRecoveryReviewer(
  sql: DbClient,
  user: UserView,
): Promise<void> {
  if (await hasAccountRecoveryReviewAccess(sql, user)) return;
  throw new WorkflowHttpError(
    'internal_role_required', 403, 'Private recovery review permission is required.',
  );
}

async function hasAccountRecoveryReviewAccess(
  sql: DbClient,
  user: UserView,
): Promise<boolean> {
  if (canApprovePlatformRoles(user.internalRoles)) return true;
  if (user.internalRoles.length === 0) return false;
  const rows = await sql`
    SELECT 1
    FROM public.hdc_internal_permission_grants
    WHERE user_id = ${user.id}
      AND permission_code = 'account_recovery.review'
      AND is_active = true
    LIMIT 1
  `;
  return rows.length > 0;
}

function requireInternalDashboardAccess(user: UserView): void {
  if (user.internalRoles.length === 0) {
    throw new WorkflowHttpError(
      'internal_access_required',
      403,
      'Private HDC workspace access is required for this action.',
    );
  }
}

function roleApplicationView(row: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = {
    id: String(row.id),
    userId: String(row.user_id),
    role: String(row.role),
    status: String(row.status),
    applicantNote: String(row.applicant_note ?? ''),
    formVersion: Number(row.form_version ?? 1),
    answers: row.answers && typeof row.answers === 'object' ? row.answers : {},
    applicantSnapshot:
      row.applicant_snapshot && typeof row.applicant_snapshot === 'object'
        ? row.applicant_snapshot
        : {},
    reviewNote: String(row.review_note ?? ''),
    reviewedBy: row.reviewed_by ? String(row.reviewed_by) : null,
    reviewedAt: row.reviewed_at
      ? new Date(String(row.reviewed_at)).toISOString()
      : null,
    submittedAt: row.submitted_at
      ? new Date(String(row.submitted_at)).toISOString()
      : null,
    changesRequestedAt: row.changes_requested_at
      ? new Date(String(row.changes_requested_at)).toISOString()
      : null,
    createdAt: new Date(String(row.created_at)).toISOString(),
    updatedAt: new Date(String(row.updated_at)).toISOString(),
  };
  if (row.display_name) result.displayName = String(row.display_name);
  if (row.email) result.email = String(row.email);
  return result;
}

function roleNotificationView(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: String(row.id),
    eventType: String(row.event_type),
    priority: String(row.priority),
    title: String(row.title),
    message: String(row.message),
    metadata: row.metadata && typeof row.metadata === 'object'
      ? row.metadata
      : {},
    readAt: row.read_at ? new Date(String(row.read_at)).toISOString() : null,
    createdAt: new Date(String(row.created_at)).toISOString(),
  };
}

function memberProfileView(row: Record<string, unknown>): Record<string, unknown> {
  return {
    userId: String(row.user_id),
    displayName: String(row.display_name),
    email: String(row.email),
    bio: String(row.bio ?? ''),
    location: String(row.location ?? ''),
    avatarUrl: String(row.avatar_url ?? ''),
    contactPreference: String(row.contact_preference ?? 'in_app'),
    version: Number(row.version ?? 1),
    createdAt: new Date(String(row.created_at)).toISOString(),
    updatedAt: new Date(String(row.updated_at)).toISOString(),
  };
}

function platformRoleProfileView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  const details = row.details && typeof row.details === 'object' &&
      !Array.isArray(row.details)
    ? row.details
    : {};
  return {
    id: String(row.id),
    userId: String(row.user_id),
    role: String(row.role),
    publicName: String(row.public_name),
    headline: String(row.headline ?? ''),
    description: String(row.description ?? ''),
    location: String(row.location ?? ''),
    contactEmail: String(row.contact_email ?? ''),
    contactPhone: String(row.contact_phone ?? ''),
    website: String(row.website ?? ''),
    isPublic: Boolean(row.is_public),
    details,
    version: Number(row.version ?? 1),
    createdAt: new Date(String(row.created_at)).toISOString(),
    updatedAt: new Date(String(row.updated_at)).toISOString(),
  };
}

function internalStaffAssignmentView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    title: String(row.title ?? ''),
    departmentCode: String(row.department_code ?? ''),
    departmentName: String(row.department_name ?? ''),
    sectionCode: row.section_code ? String(row.section_code) : null,
    sectionName: row.section_name ? String(row.section_name) : null,
    createdAt: new Date(String(row.created_at)).toISOString(),
    updatedAt: new Date(String(row.updated_at)).toISOString(),
  };
}

function internalActivityView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    eventType: String(row.event_type),
    eventStatus: String(row.event_status),
    createdAt: new Date(String(row.created_at)).toISOString(),
  };
}

async function ensureAccountProfiles(
  sql: DbClient,
  user: UserView,
): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`
      INSERT INTO public.hdc_member_profiles (user_id)
      VALUES (${user.id})
      ON CONFLICT (user_id) DO NOTHING
    `;

    for (const role of user.platformRoles) {
      await tx`
        INSERT INTO public.hdc_platform_role_profiles (
          user_id, role, public_name
        ) VALUES (
          ${user.id}, ${role}, ${user.displayName}
        )
        ON CONFLICT (user_id, role) DO NOTHING
      `;
    }
  });
}

async function handleProfilesOverview(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  await ensureAccountProfiles(sql, user);

  const memberRows = await sql`
    SELECT profile.*, member.display_name, member.email::text AS email
    FROM public.hdc_member_profiles profile
    JOIN public.hdc_users member ON member.id = profile.user_id
    WHERE profile.user_id = ${user.id}
    LIMIT 1
  `;
  const roleRows = await sql`
    SELECT profile.*
    FROM public.hdc_platform_role_profiles profile
    JOIN public.hdc_user_roles assignment
      ON assignment.user_id = profile.user_id
      AND assignment.role::text = profile.role
      AND assignment.is_active = true
    WHERE profile.user_id = ${user.id}
    ORDER BY CASE profile.role
      WHEN 'customer' THEN 1
      WHEN 'technician' THEN 2
      WHEN 'business' THEN 3
      WHEN 'seller' THEN 4
      WHEN 'supplier' THEN 5
      WHEN 'store' THEN 6
      ELSE 99
    END
  `;

  return json({
    account: {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
    },
    memberProfile: memberProfileView(rowObject(memberRows[0])),
    roleProfiles: roleRows.map((row) =>
      platformRoleProfileView(rowObject(row))),
  });
}

async function handleInternalDashboard(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  requireInternalDashboardAccess(user);

  const basePermissions = internalDashboardPermissions(user.internalRoles);
  const reviewScope = await platformRoleReviewScope(sql, user);
  const canReviewAccountRecovery = await hasAccountRecoveryReviewAccess(
    sql,
    user,
  );
  const permissions = {
    ...basePermissions,
    canApprovePlatformRoles:
      basePermissions.canApprovePlatformRoles ||
      reviewScope.allRoles ||
      reviewScope.roles.size > 0,
    canReviewAccountRecovery,
  };
  const assignmentRows = await sql`
    SELECT
      assignment.id,
      assignment.title,
      assignment.created_at,
      assignment.updated_at,
      department.code AS department_code,
      department.name AS department_name,
      section.code AS section_code,
      section.name AS section_name
    FROM public.hdc_internal_staff_assignments assignment
    JOIN public.hdc_internal_departments department
      ON department.id = assignment.department_id
    LEFT JOIN public.hdc_internal_department_sections section
      ON section.id = assignment.section_id
    WHERE assignment.user_id = ${user.id}
      AND assignment.is_active = true
      AND department.is_active = true
      AND (assignment.section_id IS NULL OR section.is_active = true)
    ORDER BY department.name, section.name NULLS FIRST
  `;

  const statistics: Record<string, number> = {
    myAssignments: assignmentRows.length,
  };

  if (permissions.canApprovePlatformRoles) {
    const rows = await sql`
      SELECT role, count(*)::int AS pending_count
      FROM public.hdc_platform_role_applications
      WHERE status IN ('submitted', 'under_review')
      GROUP BY role
    `;
    statistics.pendingRoleApplications = rows.reduce((total, row) => {
      const role = normalizeRoleCode(row.role);
      if (!role || !isApprovalPlatformRoleCode(role)) return total;
      if (!reviewScope.allRoles && !reviewScope.roles.has(role)) return total;
      return total + Number(row.pending_count ?? 0);
    }, 0);
  }

  if (permissions.canReviewAccountRecovery) {
    const rows = await sql`
      SELECT count(*)::int AS pending_count
      FROM public.hdc_account_recovery_review_requests
      WHERE status = 'pending'
    `;
    statistics.pendingRecoveryReviews = Number(rows[0]?.pending_count ?? 0);
  }

  if (permissions.canManageInternalStructure) {
    const rows = await sql`
      SELECT
        (SELECT count(*) FROM public.hdc_internal_departments
          WHERE is_active = true)::int AS active_departments,
        (SELECT count(*)
          FROM public.hdc_internal_department_sections section
          JOIN public.hdc_internal_departments department
            ON department.id = section.department_id
          WHERE section.is_active = true
            AND department.is_active = true)::int AS active_sections,
        (SELECT count(*)
          FROM public.hdc_internal_staff_assignments assignment
          JOIN public.hdc_internal_departments department
            ON department.id = assignment.department_id
          LEFT JOIN public.hdc_internal_department_sections section
            ON section.id = assignment.section_id
          WHERE assignment.is_active = true
            AND department.is_active = true
            AND (
              assignment.section_id IS NULL OR section.is_active = true
            ))::int AS active_staff_assignments
    `;
    statistics.activeDepartments = Number(rows[0]?.active_departments ?? 0);
    statistics.activeSections = Number(rows[0]?.active_sections ?? 0);
    statistics.activeStaffAssignments = Number(
      rows[0]?.active_staff_assignments ?? 0,
    );
  }

  if (permissions.hasPrivilegedResourceAccess) {
    const rows = await sql`
      SELECT
        (SELECT count(*) FROM public.hdc_users
          WHERE status = 'active')::int AS active_members,
        (SELECT count(*) FROM public.hdc_service_requests
          WHERE status IN (
            'open', 'receivingOffers', 'technicianSelected', 'inProgress'
          ))::int AS open_service_requests,
        (SELECT count(*) FROM public.hdc_service_transactions
          WHERE status NOT IN ('completed', 'cancelled'))::int
          AS active_service_transactions
    `;
    statistics.activeMembers = Number(rows[0]?.active_members ?? 0);
    statistics.openServiceRequests = Number(
      rows[0]?.open_service_requests ?? 0,
    );
    statistics.activeServiceTransactions = Number(
      rows[0]?.active_service_transactions ?? 0,
    );
  }

  const activityRows = permissions.hasPrivilegedResourceAccess
    ? await sql`
        SELECT event_type, event_status, created_at
        FROM public.hdc_security_audit
        WHERE event_type LIKE 'roles.%' OR event_type LIKE 'internal.%'
        ORDER BY created_at DESC
        LIMIT 12
      `
    : await sql`
        SELECT event_type, event_status, created_at
        FROM public.hdc_security_audit
        WHERE user_id = ${user.id}
          AND (event_type LIKE 'roles.%' OR event_type LIKE 'internal.%')
        ORDER BY created_at DESC
        LIMIT 12
      `;

  return json({
    privateWorkspace: true,
    account: {
      userId: user.id,
      displayName: user.displayName,
    },
    permissions,
    statistics,
    assignments: assignmentRows.map((row) =>
      internalStaffAssignmentView(rowObject(row))),
    recentActivities: activityRows.map((row) =>
      internalActivityView(rowObject(row))),
  });
}

async function handleUpdateMemberProfile(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = normalizeMemberProfileWrite(body);
  if (!input) {
    return json({
      error: 'invalid_member_profile',
      message: 'Check the shared account profile fields and try again.',
    }, 400);
  }

  const rows = await sql.begin(async (tx) => {
    await tx`
      UPDATE public.hdc_users
      SET display_name = ${input.displayName}, updated_at = now()
      WHERE id = ${user.id}
    `;
    return await tx`
      INSERT INTO public.hdc_member_profiles (
        user_id, bio, location, avatar_url, contact_preference
      ) VALUES (
        ${user.id}, ${input.bio}, ${input.location}, ${input.avatarUrl},
        ${input.contactPreference}
      )
      ON CONFLICT (user_id) DO UPDATE SET
        bio = EXCLUDED.bio,
        location = EXCLUDED.location,
        avatar_url = EXCLUDED.avatar_url,
        contact_preference = EXCLUDED.contact_preference
      RETURNING *
    `;
  });

  const updatedUser = await getUserView(sql, user.id);
  if (!updatedUser) {
    throw new WorkflowHttpError(
      'profile_account_not_found',
      404,
      'The HDC account is no longer available.',
    );
  }
  await audit(sql, user.id, 'profiles.member.update', 'success', {
    profile_type: 'member',
  });
  return json({
    user: updatedUser,
    memberProfile: memberProfileView({
      ...rowObject(rows[0]),
      display_name: updatedUser.displayName,
      email: updatedUser.email,
    }),
  });
}

async function handleUpdatePlatformRoleProfile(
  req: Request,
  sql: DbClient,
  user: UserView,
  roleValue: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const normalizedRole = normalizeRoleCode(roleValue);
  if (!normalizedRole || !isPlatformRoleCode(normalizedRole)) {
    return json({ error: 'invalid_platform_role' }, 400);
  }
  const role = normalizedRole;
  if (!user.platformRoles.includes(role)) {
    return json({
      error: 'profile_role_inactive',
      message: 'Activate this platform role before editing its profile.',
    }, 403);
  }

  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = normalizePlatformRoleProfileWrite(role, body);
  if (!input) {
    return json({
      error: 'invalid_role_profile',
      message: `Check the ${role} profile fields and try again.`,
    }, 400);
  }

  const rows = await sql`
    INSERT INTO public.hdc_platform_role_profiles (
      user_id,
      role,
      public_name,
      headline,
      description,
      location,
      contact_email,
      contact_phone,
      website,
      is_public,
      details
    ) VALUES (
      ${user.id},
      ${role},
      ${input.publicName},
      ${input.headline},
      ${input.description},
      ${input.location},
      ${input.contactEmail},
      ${input.contactPhone},
      ${input.website},
      ${input.isPublic},
      ${sql.json(input.details)}
    )
    ON CONFLICT (user_id, role) DO UPDATE SET
      public_name = EXCLUDED.public_name,
      headline = EXCLUDED.headline,
      description = EXCLUDED.description,
      location = EXCLUDED.location,
      contact_email = EXCLUDED.contact_email,
      contact_phone = EXCLUDED.contact_phone,
      website = EXCLUDED.website,
      is_public = EXCLUDED.is_public,
      details = EXCLUDED.details
    RETURNING *
  `;

  await audit(sql, user.id, 'profiles.role.update', 'success', {
    platform_role: role,
  });
  return json({
    roleProfile: platformRoleProfileView(rowObject(rows[0])),
  });
}

async function handleRoleOverview(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();

  const applications = await sql`
    SELECT *
    FROM public.hdc_platform_role_applications
    WHERE user_id = ${user.id}
    ORDER BY created_at DESC
    LIMIT 50
  `;
  const notifications = await sql`
    SELECT *
    FROM public.hdc_notifications
    WHERE user_id = ${user.id}
      AND event_type LIKE 'roles.%'
    ORDER BY created_at DESC
    LIMIT 50
  `;

  return json({
    platformRoles: [...user.platformRoles],
    applications: applications.map((row) => roleApplicationView(rowObject(row))),
    notifications: notifications.map((row) => roleNotificationView(rowObject(row))),
  });
}

async function handleCreateRoleApplication(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);

  const normalizedRole = normalizeRoleCode(body.role);
  if (!normalizedRole || !isApprovalPlatformRoleCode(normalizedRole)) {
    return json({
      error: 'invalid_platform_role',
      message: 'Choose an HDC platform role that accepts applications.',
    }, 400);
  }
  const role = normalizedRole;
  if (user.platformRoles.includes(role)) {
    return json({ error: 'platform_role_already_active' }, 409);
  }

  const applicantNote = normalizeRoleApplicationNote(body.note);
  if (applicantNote === null) {
    return json({
      error: 'invalid_application_note',
      message: 'The application note must be 1,000 characters or fewer.',
    }, 400);
  }

  const answers = normalizeRoleApplicationAnswers(role, body.answers);
  if (!answers) {
    return json({
      error: 'invalid_role_application',
      message: `Complete every required ${role} application field and confirmation.`,
    }, 400);
  }

  const applicationId = randomUUID();
  try {
    const application = await sql.begin(async (tx) => {
      const existingRows = await tx`
        SELECT id
        FROM public.hdc_platform_role_applications
        WHERE user_id = ${user.id}
          AND role = ${role}
          AND status = 'changes_requested'
        ORDER BY updated_at DESC
        LIMIT 1
        FOR UPDATE
      `;
      const snapshot = {
        displayName: user.displayName,
        email: user.email,
        publicMemberId: user.publicMemberId,
        platformRoles: user.platformRoles,
      };
      const rows = existingRows.length > 0
        ? await tx`
            UPDATE public.hdc_platform_role_applications
            SET
              status = 'submitted',
              form_version = ${ROLE_APPLICATION_FORM_VERSION},
              answers = ${tx.json(answers)},
              applicant_snapshot = ${tx.json(snapshot)},
              applicant_note = ${applicantNote},
              review_note = '',
              reviewed_by = NULL,
              reviewed_at = NULL,
              submitted_at = now(),
              changes_requested_at = NULL
            WHERE id = ${String(existingRows[0].id)}
            RETURNING *
          `
        : await tx`
            INSERT INTO public.hdc_platform_role_applications (
              id, user_id, role, status, form_version, answers,
              applicant_snapshot, applicant_note, submitted_at
            ) VALUES (
              ${applicationId}, ${user.id}, ${role}, 'submitted',
              ${ROLE_APPLICATION_FORM_VERSION}, ${tx.json(answers)},
              ${tx.json(snapshot)}, ${applicantNote}, now()
            )
            RETURNING *
          `;
      const savedApplicationId = String(rows[0].id);

      await tx`
        INSERT INTO public.hdc_notifications (
          user_id, event_type, priority, title, message, metadata
        )
        SELECT
          assignment.user_id,
          'roles.application_submitted',
          'high',
          'Platform role application',
          ${`${user.displayName} applied for the ${role} platform role.`},
          ${tx.json({
            applicationId: savedApplicationId,
            applicantUserId: user.id,
            platformRole: role,
          })}
        FROM public.hdc_internal_role_assignments assignment
        WHERE assignment.is_active = true
          AND assignment.role IN ('owner', 'super_admin')
      `;

      return rowObject(rows[0]);
    });

    await audit(sql, user.id, 'roles.application.submit', 'success', {
      application_id: String(application.id),
      platform_role: role,
      form_version: ROLE_APPLICATION_FORM_VERSION,
    });
    return json({ application: roleApplicationView(application) }, 201);
  } catch (error) {
    const code = typeof error === 'object' && error !== null && 'code' in error
      ? String((error as { code?: unknown }).code ?? '')
      : '';
    if (code === '23505') {
      return json({ error: 'platform_role_application_pending' }, 409);
    }
    throw error;
  }
}

async function handleListRoleApplications(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  const scope = await requirePlatformRoleApprover(sql, user);

  const rows = await sql`
    SELECT application.*, applicant.display_name, applicant.email::text AS email
    FROM public.hdc_platform_role_applications application
    JOIN public.hdc_users applicant ON applicant.id = application.user_id
    WHERE application.status IN ('submitted', 'under_review')
    ORDER BY application.created_at ASC
    LIMIT 200
  `;

  return json({
    applications: rows
      .filter((row) => {
        const role = normalizeRoleCode(row.role);
        return role !== null && isApprovalPlatformRoleCode(role) &&
          (scope.allRoles || scope.roles.has(role));
      })
      .map((row) => roleApplicationView(rowObject(row))),
  });
}

async function handleReviewRoleApplication(
  req: Request,
  sql: DbClient,
  reviewer: UserView,
  applicationId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();

  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const decision = normalizeRoleCode(body.decision);
  if (
    decision !== 'approved' && decision !== 'rejected' &&
    decision !== 'changes_requested'
  ) {
    return json({ error: 'invalid_role_decision' }, 400);
  }
  const reviewNote = normalizeRoleApplicationNote(body.note);
  if (
    reviewNote === null ||
    ((decision === 'rejected' || decision === 'changes_requested') &&
      reviewNote.length === 0)
  ) {
    return json({
      error: 'invalid_review_note',
      message: 'A rejection or change request requires a review note of 1,000 characters or fewer.',
    }, 400);
  }

  const application = await sql.begin(async (tx) => {
    const currentRows = await tx`
      SELECT *
      FROM public.hdc_platform_role_applications
      WHERE id = ${applicationId}
      FOR UPDATE
    `;
    if (currentRows.length === 0) {
      throw new WorkflowHttpError(
        'role_application_not_found',
        404,
        'The platform role application was not found.',
      );
    }

    const current = rowObject(currentRows[0]);
    if (!['submitted', 'under_review'].includes(String(current.status))) {
      throw new WorkflowHttpError(
        'role_application_already_reviewed',
        409,
        'The platform role application has already been reviewed.',
      );
    }
    const role = normalizeRoleCode(current.role);
    if (!role || !isApprovalPlatformRoleCode(role)) {
      throw new WorkflowHttpError(
        'invalid_platform_role',
        409,
        'The application contains an invalid platform role.',
      );
    }
    await requirePlatformRoleApprover(tx as unknown as DbClient, reviewer, role);
    const applicantUserId = String(current.user_id);

    if (decision === 'approved') {
      await tx`
        INSERT INTO public.hdc_user_roles (
          user_id, role, is_active, status, source_application_id,
          granted_by, granted_at, updated_at
        ) VALUES (
          ${applicantUserId}, ${role}::public.hdc_account_role, true,
          'active', ${applicationId}, ${reviewer.id}, now(), now()
        )
        ON CONFLICT (user_id, role) DO UPDATE
        SET is_active = true,
            status = 'active',
            source_application_id = EXCLUDED.source_application_id,
            granted_by = EXCLUDED.granted_by,
            granted_at = now(),
            suspended_at = NULL,
            revoked_at = NULL,
            updated_at = now()
      `;
    }

    const updatedRows = await tx`
      UPDATE public.hdc_platform_role_applications
      SET
        status = ${decision},
        review_note = ${reviewNote},
        reviewed_by = ${reviewer.id},
        reviewed_at = now(),
        changes_requested_at = CASE
          WHEN ${decision} = 'changes_requested' THEN now()
          ELSE changes_requested_at
        END
      WHERE id = ${applicationId}
      RETURNING *
    `;

    await tx`
      INSERT INTO public.hdc_notifications (
        user_id, event_type, priority, title, message, metadata
      ) VALUES (
        ${applicantUserId},
        ${decision === 'approved'
          ? 'roles.application_approved'
          : decision === 'changes_requested'
            ? 'roles.application_changes_requested'
            : 'roles.application_rejected'},
        'high',
        ${decision === 'approved' ? 'Platform role approved' : 'Platform role update'},
        ${decision === 'approved'
          ? `Your ${role} platform role is now active.`
          : decision === 'changes_requested'
            ? `Changes are required for your ${role} platform role application.`
            : `Your ${role} platform role application was not approved.`},
        ${tx.json({
          applicationId,
          platformRole: role,
          decision,
          reviewedBy: reviewer.id,
        })}
      )
    `;

    return rowObject(updatedRows[0]);
  });

  await audit(sql, reviewer.id, 'roles.application.review', 'success', {
    application_id: applicationId,
    decision,
  });
  return json({ application: roleApplicationView(application) });
}

async function withWorkflowAuthority<T>(
  sql: DbClient,
  user: UserView,
  operation: (tx: DbClient) => Promise<T>,
): Promise<T> {
  const roles = user.platformRoles.join(',');
  const result = await sql.begin(async (tx) => {
    await tx`
      SELECT
        set_config('hdc.user_id', ${user.id}, true),
        set_config('hdc.roles', ${roles}, true)
    `;
    await tx.unsafe('SET LOCAL ROLE hdc_app');
    return operation(tx as unknown as DbClient);
  });
  return result as T;
}

function rowObject(value: unknown): Record<string, unknown> {
  return value as Record<string, unknown>;
}

async function handleWorkflowBootstrap(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();

  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    const requests = await tx`
      SELECT *
      FROM public.hdc_service_requests
      ORDER BY updated_at DESC
    `;
    const proposals = await tx`
      SELECT *
      FROM public.hdc_proposals
      ORDER BY updated_at DESC
    `;
    const seeds = await tx`
      SELECT *
      FROM public.hdc_transaction_seeds
      ORDER BY created_at DESC
    `;
    const transactions = await tx`
      SELECT *
      FROM public.hdc_service_transactions
      ORDER BY updated_at DESC
    `;

    return {
      serviceRequests: requests.map((row) => serviceRequestView(rowObject(row))),
      proposals: proposals.map((row) => proposalView(rowObject(row))),
      transactionSeeds: seeds.map((row) => transactionSeedView(rowObject(row))),
      serviceTransactions: transactions.map((row) => serviceTransactionView(rowObject(row))),
    };
  });

  return json(result);
}

async function handleCreateServiceRequest(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  requireWorkflowRole(user, 'customer');
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseServiceRequestWrite(body);
  if (input.status !== 'draft' && input.status !== 'open') {
    throw new WorkflowHttpError(
      'invalid_request_status',
      409,
      'A new service request must start as draft or open.',
    );
  }

  const created = await withWorkflowAuthority(sql, user, async (tx) => {
    const rows = await tx`
      INSERT INTO public.hdc_service_requests (
        id, customer_id, customer_name, title, category_id, category_name,
        description, location, preferred_date, preferred_time, urgency,
        minimum_budget, maximum_budget, status
      ) VALUES (
        ${input.id}, ${user.id}, ${user.displayName}, ${input.title},
        ${input.categoryId}, ${input.categoryName}, ${input.description},
        ${input.location}, ${input.preferredDate}, ${input.preferredTime},
        ${input.urgency}, ${input.minimumBudget}, ${input.maximumBudget},
        ${input.status}
      )
      RETURNING *
    `;
    return serviceRequestView(rowObject(rows[0]));
  });

  await audit(sql, user.id, 'workflow.request.create', 'success', {
    request_id: input.id,
  });
  return json({ serviceRequest: created }, 201);
}

async function handleUpdateServiceRequest(
  req: Request,
  sql: DbClient,
  user: UserView,
  requestId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  requireWorkflowRole(user, 'customer');
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseServiceRequestWrite(body);
  if (input.id !== requestId) {
    throw new WorkflowHttpError('identifier_mismatch', 400, 'Request identifiers do not match.');
  }

  const updated = await withWorkflowAuthority(sql, user, async (tx) => {
    const existingRows = await tx`
      SELECT *
      FROM public.hdc_service_requests
      WHERE id = ${requestId}
      FOR UPDATE
    `;
    if (existingRows.length === 0) {
      throw new WorkflowHttpError('service_request_not_found', 404, 'Service request not found.');
    }
    const existing = rowObject(existingRows[0]);
    if (String(existing.customer_id) !== user.id) {
      throw new WorkflowHttpError('forbidden', 403, 'Only the request owner can edit it.');
    }

    const currentStatus = String(existing.status);
    if (!canCustomerUpdateRequestStatus(currentStatus, input.status)) {
      throw new WorkflowHttpError(
        'invalid_request_transition',
        409,
        `The request cannot move from ${currentStatus} to ${input.status}.`,
      );
    }
    if (!['draft', 'open', 'receivingOffers'].includes(currentStatus)) {
      throw new WorkflowHttpError(
        'request_not_editable',
        409,
        'This service request can no longer be edited.',
      );
    }

    let updatedProposals: Record<string, unknown>[] = [];
    if (input.status === 'cancelled' && currentStatus !== 'cancelled') {
      const proposalRows = await tx`
        UPDATE public.hdc_proposals
        SET
          status = CASE WHEN status = 'draft' THEN 'expired' ELSE 'declined' END,
          expired_at = CASE
            WHEN status = 'draft' THEN COALESCE(expired_at, now())
            ELSE expired_at
          END,
          declined_at = CASE
            WHEN status IN ('submitted', 'viewed', 'shortlisted')
              THEN COALESCE(declined_at, now())
            ELSE declined_at
          END
        WHERE request_id = ${requestId}
          AND status IN ('draft', 'submitted', 'viewed', 'shortlisted')
        RETURNING *
      `;
      updatedProposals = proposalRows.map((row) => rowObject(row));
    }

    const rows = await tx`
      UPDATE public.hdc_service_requests
      SET
        title = ${input.title},
        category_id = ${input.categoryId},
        category_name = ${input.categoryName},
        description = ${input.description},
        location = ${input.location},
        preferred_date = ${input.preferredDate},
        preferred_time = ${input.preferredTime},
        urgency = ${input.urgency},
        minimum_budget = ${input.minimumBudget},
        maximum_budget = ${input.maximumBudget},
        status = ${input.status}
      WHERE id = ${requestId}
      RETURNING *
    `;
    return {
      serviceRequest: serviceRequestView(rowObject(rows[0])),
      updatedProposals: updatedProposals.map((row) => proposalView(row)),
    };
  });

  await audit(sql, user.id, 'workflow.request.update', 'success', {
    request_id: requestId,
    status: input.status,
  });
  return json(updated);
}

async function handleDeleteServiceRequest(
  req: Request,
  sql: DbClient,
  user: UserView,
  requestId: string,
): Promise<Response> {
  if (req.method !== 'DELETE') return methodNotAllowed();
  requireWorkflowRole(user, 'customer');

  await withWorkflowAuthority(sql, user, async (tx) => {
    const rows = await tx`
      DELETE FROM public.hdc_service_requests
      WHERE id = ${requestId}
        AND customer_id = ${user.id}
        AND status = 'draft'
      RETURNING id
    `;
    if (rows.length === 0) {
      throw new WorkflowHttpError(
        'service_request_not_deletable',
        409,
        'Only an owned draft request can be deleted.',
      );
    }
  });

  await audit(sql, user.id, 'workflow.request.delete', 'success', {
    request_id: requestId,
  });
  return json({ success: true });
}

async function handleCreateProposal(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  requireWorkflowRole(user, 'technician');
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseProposalWrite(body);
  if (input.status !== 'draft' && input.status !== 'submitted') {
    throw new WorkflowHttpError(
      'invalid_proposal_status',
      409,
      'A new proposal must start as draft or submitted.',
    );
  }
  const score = proposalQualityScore(input);
  if (input.status === 'submitted' && score < 40) {
    throw new WorkflowHttpError(
      'proposal_incomplete',
      409,
      'Complete more proposal details before submitting.',
    );
  }
  const reputation = technicianReputation(workflowUser(user));

  const created = await withWorkflowAuthority(sql, user, async (tx) => {
    const requestRows = await tx`
      SELECT id, status
      FROM public.hdc_service_requests
      WHERE id = ${input.requestId}
      FOR UPDATE
    `;
    if (requestRows.length === 0) {
      throw new WorkflowHttpError('service_request_not_found', 404, 'Service request not found.');
    }
    if (!['open', 'receivingOffers'].includes(String(requestRows[0].status))) {
      throw new WorkflowHttpError(
        'request_not_accepting_proposals',
        409,
        'This request is no longer accepting proposals.',
      );
    }

    const rows = await tx`
      INSERT INTO public.hdc_proposals (
        id, request_id, technician_id, status, service_fee,
        parts_arrangement, estimated_parts_cost, earliest_arrival,
        estimated_duration_minutes, warranty_type, custom_warranty_days,
        diagnosis, repair_approach, professional_notes, reputation,
        quality_score, attachment_ids, submitted_at
      ) VALUES (
        ${input.id}, ${input.requestId}, ${user.id}, ${input.status},
        ${input.serviceFee}, ${input.partsArrangement},
        ${input.estimatedPartsCost}, ${input.earliestArrival},
        ${input.estimatedDurationMinutes}, ${input.warrantyType},
        ${input.customWarrantyDays}, ${input.diagnosis},
        ${input.repairApproach}, ${input.professionalNotes},
        ${tx.json(reputation)}, ${score}, ${tx.json(input.attachmentIds)},
        ${input.status === 'submitted' ? new Date() : null}
      )
      RETURNING *
    `;
    const updatedRequestRows = await tx`
      SELECT *
      FROM public.hdc_service_requests
      WHERE id = ${input.requestId}
      LIMIT 1
    `;
    return {
      proposal: proposalView(rowObject(rows[0])),
      updatedRequest: serviceRequestView(rowObject(updatedRequestRows[0])),
    };
  });

  await audit(sql, user.id, 'workflow.proposal.create', 'success', {
    proposal_id: input.id,
    request_id: input.requestId,
    status: input.status,
  });
  return json(created, 201);
}

async function handleUpdateProposal(
  req: Request,
  sql: DbClient,
  user: UserView,
  proposalId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseProposalWrite(body);
  if (input.id !== proposalId) {
    throw new WorkflowHttpError('identifier_mismatch', 400, 'Proposal identifiers do not match.');
  }

  const updated = await withWorkflowAuthority(sql, user, async (tx) => {
    const proposalReferenceRows = await tx`
      SELECT request_id
      FROM public.hdc_proposals
      WHERE id = ${proposalId}
    `;
    if (proposalReferenceRows.length === 0) {
      throw new WorkflowHttpError('proposal_not_found', 404, 'Proposal not found.');
    }
    const requestId = String(proposalReferenceRows[0].request_id);
    const requestRows = await tx`
      SELECT customer_id
      FROM public.hdc_service_requests
      WHERE id = ${requestId}
      FOR UPDATE
    `;
    if (requestRows.length === 0) {
      throw new WorkflowHttpError('service_request_not_found', 404, 'Service request not found.');
    }
    const proposalRows = await tx`
      SELECT *
      FROM public.hdc_proposals
      WHERE id = ${proposalId}
        AND request_id = ${requestId}
      FOR UPDATE
    `;
    if (proposalRows.length === 0) {
      throw new WorkflowHttpError('proposal_not_found', 404, 'Proposal not found.');
    }
    const current = rowObject(proposalRows[0]);

    const currentStatus = String(current.status);
    const technicianOwns = String(current.technician_id) === user.id;
    const customerOwns = String(requestRows[0].customer_id) === user.id;
    if (!technicianOwns && !customerOwns) {
      throw new WorkflowHttpError('forbidden', 403, 'You cannot update this proposal.');
    }

    if (technicianOwns) {
      requireWorkflowRole(user, 'technician');
      if (!canTechnicianUpdateProposalStatus(currentStatus, input.status)) {
        throw new WorkflowHttpError(
          'invalid_proposal_transition',
          409,
          `The proposal cannot move from ${currentStatus} to ${input.status}.`,
        );
      }
      if (currentStatus !== 'draft' && input.status !== 'withdrawn') {
        throw new WorkflowHttpError(
          'proposal_not_editable',
          409,
          'Only a draft proposal can be edited.',
        );
      }

      const score = proposalQualityScore(input);
      if (input.status === 'submitted' && score < 40) {
        throw new WorkflowHttpError(
          'proposal_incomplete',
          409,
          'Complete more proposal details before submitting.',
        );
      }
      const reputation = technicianReputation(workflowUser(user));
      const rows = await tx`
        UPDATE public.hdc_proposals
        SET
          status = ${input.status},
          service_fee = ${input.serviceFee},
          parts_arrangement = ${input.partsArrangement},
          estimated_parts_cost = ${input.estimatedPartsCost},
          earliest_arrival = ${input.earliestArrival},
          estimated_duration_minutes = ${input.estimatedDurationMinutes},
          warranty_type = ${input.warrantyType},
          custom_warranty_days = ${input.customWarrantyDays},
          diagnosis = ${input.diagnosis},
          repair_approach = ${input.repairApproach},
          professional_notes = ${input.professionalNotes},
          reputation = ${tx.json(reputation)},
          quality_score = ${score},
          attachment_ids = ${tx.json(input.attachmentIds)},
          submitted_at = CASE
            WHEN ${input.status} = 'submitted' THEN COALESCE(submitted_at, now())
            ELSE submitted_at
          END,
          withdrawn_at = CASE
            WHEN ${input.status} = 'withdrawn' THEN COALESCE(withdrawn_at, now())
            ELSE withdrawn_at
          END
        WHERE id = ${proposalId}
        RETURNING *
      `;
      const updatedRequestRows = await tx`
        SELECT *
        FROM public.hdc_service_requests
        WHERE id = ${requestId}
        LIMIT 1
      `;
      return {
        proposal: proposalView(rowObject(rows[0])),
        updatedRequest: serviceRequestView(rowObject(updatedRequestRows[0])),
      };
    }

    requireWorkflowRole(user, 'customer');
    if (!canCustomerUpdateProposalStatus(currentStatus, input.status)) {
      throw new WorkflowHttpError(
        'invalid_proposal_transition',
        409,
        `The proposal cannot move from ${currentStatus} to ${input.status}.`,
      );
    }

    const rows = await tx`
      UPDATE public.hdc_proposals
      SET
        status = ${input.status},
        viewed_at = CASE
          WHEN ${input.status} IN ('viewed', 'shortlisted')
            THEN COALESCE(viewed_at, now())
          ELSE viewed_at
        END,
        shortlisted_at = CASE
          WHEN ${input.status} = 'shortlisted' THEN COALESCE(shortlisted_at, now())
          WHEN ${input.status} = 'viewed' THEN NULL
          ELSE shortlisted_at
        END,
        declined_at = CASE
          WHEN ${input.status} = 'declined' THEN COALESCE(declined_at, now())
          ELSE declined_at
        END
      WHERE id = ${proposalId}
      RETURNING *
    `;
    const updatedRequestRows = await tx`
      SELECT *
      FROM public.hdc_service_requests
      WHERE id = ${requestId}
      LIMIT 1
    `;
    return {
      proposal: proposalView(rowObject(rows[0])),
      updatedRequest: serviceRequestView(rowObject(updatedRequestRows[0])),
    };
  });

  await audit(sql, user.id, 'workflow.proposal.update', 'success', {
    proposal_id: proposalId,
    status: input.status,
  });
  return json(updated);
}

async function handleDeleteProposal(
  req: Request,
  sql: DbClient,
  user: UserView,
  proposalId: string,
): Promise<Response> {
  if (req.method !== 'DELETE') return methodNotAllowed();
  requireWorkflowRole(user, 'technician');

  await withWorkflowAuthority(sql, user, async (tx) => {
    const rows = await tx`
      DELETE FROM public.hdc_proposals
      WHERE id = ${proposalId}
        AND technician_id = ${user.id}
        AND status = 'draft'
      RETURNING id
    `;
    if (rows.length === 0) {
      throw new WorkflowHttpError(
        'proposal_not_deletable',
        409,
        'Only your own draft proposal can be deleted.',
      );
    }
  });

  await audit(sql, user.id, 'workflow.proposal.delete', 'success', {
    proposal_id: proposalId,
  });
  return json({ success: true });
}

function acceptedWarrantyDays(proposal: Record<string, unknown>): number {
  switch (String(proposal.warranty_type)) {
    case 'sevenDays':
      return 7;
    case 'thirtyDays':
      return 30;
    case 'ninetyDays':
      return 90;
    case 'custom':
      return Number(proposal.custom_warranty_days ?? 0);
    case 'none':
    default:
      return 0;
  }
}

async function handleAcceptProposal(
  req: Request,
  sql: DbClient,
  user: UserView,
  proposalId: string,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  requireWorkflowRole(user, 'customer');

  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    const proposalReferenceRows = await tx`
      SELECT request_id
      FROM public.hdc_proposals
      WHERE id = ${proposalId}
    `;
    if (proposalReferenceRows.length === 0) {
      throw new WorkflowHttpError('proposal_not_found', 404, 'Proposal not found.');
    }
    const requestId = String(proposalReferenceRows[0].request_id);

    const requestRows = await tx`
      SELECT *
      FROM public.hdc_service_requests
      WHERE id = ${requestId}
      FOR UPDATE
    `;
    if (requestRows.length === 0) {
      throw new WorkflowHttpError('service_request_not_found', 404, 'Service request not found.');
    }
    const serviceRequest = rowObject(requestRows[0]);
    if (String(serviceRequest.customer_id) !== user.id) {
      throw new WorkflowHttpError(
        'forbidden',
        403,
        'Only the request owner can accept a proposal.',
      );
    }
    const proposalRows = await tx`
      SELECT *
      FROM public.hdc_proposals
      WHERE id = ${proposalId}
        AND request_id = ${requestId}
      FOR UPDATE
    `;
    if (proposalRows.length === 0) {
      throw new WorkflowHttpError('proposal_not_found', 404, 'Proposal not found.');
    }
    const proposal = rowObject(proposalRows[0]);

    const existingSeedRows = await tx`
      SELECT *
      FROM public.hdc_transaction_seeds
      WHERE request_id = ${String(serviceRequest.id)}
      FOR UPDATE
    `;
    if (existingSeedRows.length > 0) {
      const existingSeed = rowObject(existingSeedRows[0]);
      if (String(existingSeed.proposal_id) !== proposalId) {
        throw new WorkflowHttpError(
          'technician_already_selected',
          409,
          'A technician has already been selected for this request.',
        );
      }
      const transactionRows = await tx`
        SELECT *
        FROM public.hdc_service_transactions
        WHERE seed_id = ${String(existingSeed.id)}
        LIMIT 1
      `;
      if (transactionRows.length === 0) {
        throw new WorkflowHttpError(
          'transaction_handoff_incomplete',
          409,
          'The existing transaction handoff is incomplete.',
        );
      }
      const competingProposalRows = await tx`
        SELECT *
        FROM public.hdc_proposals
        WHERE request_id = ${String(serviceRequest.id)}
          AND id <> ${proposalId}
        ORDER BY updated_at DESC
      `;
      return {
        acceptedProposal: proposalView(proposal),
        updatedRequest: serviceRequestView(serviceRequest),
        transactionSeed: transactionSeedView(existingSeed),
        serviceTransaction: serviceTransactionView(rowObject(transactionRows[0])),
        competingProposals: competingProposalRows.map(
          (row) => proposalView(rowObject(row)),
        ),
        competingProposalsClosed: 0,
      };
    }

    const proposalStatus = String(proposal.status);
    if (!['submitted', 'viewed', 'shortlisted'].includes(proposalStatus)) {
      throw new WorkflowHttpError(
        'proposal_not_eligible',
        409,
        'This proposal is no longer eligible for acceptance.',
      );
    }
    if (!['open', 'receivingOffers'].includes(String(serviceRequest.status))) {
      throw new WorkflowHttpError(
        'request_not_accepting_proposals',
        409,
        'This request is no longer accepting proposals.',
      );
    }

    const now = new Date();
    const competingRows = await tx`
      UPDATE public.hdc_proposals
      SET
        status = 'declined',
        declined_at = COALESCE(declined_at, ${now})
      WHERE request_id = ${String(serviceRequest.id)}
        AND id <> ${proposalId}
        AND status IN ('submitted', 'viewed', 'shortlisted')
      RETURNING *
    `;

    const acceptedRows = await tx`
      UPDATE public.hdc_proposals
      SET
        status = 'accepted',
        viewed_at = COALESCE(viewed_at, ${now}),
        accepted_at = COALESCE(accepted_at, ${now})
      WHERE id = ${proposalId}
      RETURNING *
    `;
    const acceptedProposal = rowObject(acceptedRows[0]);

    const updatedRequestRows = await tx`
      UPDATE public.hdc_service_requests
      SET status = 'technicianSelected'
      WHERE id = ${String(serviceRequest.id)}
      RETURNING *
    `;
    const updatedRequest = rowObject(updatedRequestRows[0]);

    const serviceFee = Number(acceptedProposal.service_fee);
    const estimatedPartsCost = acceptedProposal.estimated_parts_cost === null
      ? null
      : Number(acceptedProposal.estimated_parts_cost);
    const totalEstimate = serviceFee + (estimatedPartsCost ?? 0);
    const seedId = newWorkflowId('TXN-SEED');
    const transactionId = newWorkflowId('TXN');
    const reputation = acceptedProposal.reputation &&
        typeof acceptedProposal.reputation === 'object' &&
        !Array.isArray(acceptedProposal.reputation)
      ? acceptedProposal.reputation as Record<string, unknown>
      : {};
    const technicianName = typeof reputation.technicianName === 'string' &&
        reputation.technicianName.trim().length > 0
      ? reputation.technicianName.trim()
      : String(acceptedProposal.technician_id);

    const acceptedTerms = {
      serviceFee,
      estimatedPartsCost,
      totalEstimate,
      earliestArrival: new Date(String(acceptedProposal.earliest_arrival)).toISOString(),
      estimatedDurationMinutes: Number(acceptedProposal.estimated_duration_minutes),
      warrantyDays: acceptedWarrantyDays(acceptedProposal),
      diagnosis: String(acceptedProposal.diagnosis),
      repairApproach: String(acceptedProposal.repair_approach),
      professionalNotes: String(acceptedProposal.professional_notes),
    };
    const activity = [
      {
        id: `${transactionId}-ACT-1`,
        type: 'transactionCreated',
        message: 'Service transaction created from the accepted proposal.',
        createdAt: now.toISOString(),
        fromStatus: null,
        toStatus: 'created',
        actorId: user.id,
      },
      {
        id: `${transactionId}-ACT-2`,
        type: 'transactionConfirmed',
        message: 'Customer and technician service relationship confirmed.',
        createdAt: now.toISOString(),
        fromStatus: 'created',
        toStatus: 'confirmed',
        actorId: user.id,
      },
    ];

    const seedRows = await tx`
      INSERT INTO public.hdc_transaction_seeds (
        id, request_id, proposal_id, customer_id, technician_id,
        accepted_estimate, status, created_at
      ) VALUES (
        ${seedId}, ${String(serviceRequest.id)}, ${proposalId}, ${user.id},
        ${String(acceptedProposal.technician_id)}, ${totalEstimate},
        'consumed', ${now}
      )
      RETURNING *
    `;

    const transactionRows = await tx`
      INSERT INTO public.hdc_service_transactions (
        id, seed_id, request_id, proposal_id, customer_id, customer_name,
        technician_id, technician_name, request_title, category_name,
        service_location, status, accepted_terms, activity, created_at,
        updated_at
      ) VALUES (
        ${transactionId}, ${seedId}, ${String(serviceRequest.id)},
        ${proposalId}, ${user.id}, ${String(serviceRequest.customer_name)},
        ${String(acceptedProposal.technician_id)}, ${technicianName},
        ${String(serviceRequest.title)}, ${String(serviceRequest.category_name)},
        ${String(serviceRequest.location)}, 'confirmed',
        ${tx.json(acceptedTerms)}, ${tx.json(activity)}, ${now}, ${now}
      )
      RETURNING *
    `;
    const canonicalCompetingRows = await tx`
      SELECT *
      FROM public.hdc_proposals
      WHERE request_id = ${String(serviceRequest.id)}
        AND id <> ${proposalId}
      ORDER BY updated_at DESC
    `;

    return {
      acceptedProposal: proposalView(acceptedProposal),
      updatedRequest: serviceRequestView(updatedRequest),
      transactionSeed: transactionSeedView(rowObject(seedRows[0])),
      serviceTransaction: serviceTransactionView(rowObject(transactionRows[0])),
      competingProposals: canonicalCompetingRows.map(
        (row) => proposalView(rowObject(row)),
      ),
      competingProposalsClosed: competingRows.length,
    };
  });

  await audit(sql, user.id, 'workflow.proposal.accept', 'success', {
    proposal_id: proposalId,
    request_id: String((result.updatedRequest as Record<string, unknown>).id),
    transaction_id: String((result.serviceTransaction as Record<string, unknown>).id),
  });
  return json(result);
}

async function handleTransactionStatus(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const nextStatus = body.status;
  if (typeof nextStatus !== 'string') {
    throw new WorkflowHttpError(
      'invalid_transaction_status',
      400,
      'A valid transaction status is required.',
    );
  }

  const updated = await withWorkflowAuthority(sql, user, async (tx) => {
    const rows = await tx`
      SELECT *
      FROM public.hdc_service_transactions
      WHERE id = ${transactionId}
      FOR UPDATE
    `;
    if (rows.length === 0) {
      throw new WorkflowHttpError(
        'service_transaction_not_found',
        404,
        'Service transaction not found.',
      );
    }
    const current = rowObject(rows[0]);
    const actorRole = String(current.customer_id) === user.id
      ? 'customer'
      : String(current.technician_id) === user.id
        ? 'technician'
        : null;
    if (!actorRole) {
      throw new WorkflowHttpError(
        'forbidden',
        403,
        'Only a transaction participant can update it.',
      );
    }

    const transition = transactionTransition(
      String(current.status),
      nextStatus,
      actorRole,
    );
    if (!transition) {
      throw new WorkflowHttpError(
        'invalid_transaction_transition',
        409,
        `The transaction cannot move from ${String(current.status)} to ${nextStatus}.`,
      );
    }

    const now = new Date();
    const currentActivity = Array.isArray(current.activity) ? current.activity : [];
    const activity = [
      ...currentActivity,
      {
        id: newWorkflowId('TXN-ACT'),
        type: transition.activityType,
        message: transition.message,
        createdAt: now.toISOString(),
        fromStatus: String(current.status),
        toStatus: nextStatus,
        actorId: user.id,
      },
    ];

    const updatedRows = await tx`
      UPDATE public.hdc_service_transactions
      SET status = ${nextStatus}, activity = ${tx.json(activity)}
      WHERE id = ${transactionId}
      RETURNING *
    `;

    let updatedRequest: Record<string, unknown>;
    if (transition.requestStatus) {
      const requestRows = await tx`
        UPDATE public.hdc_service_requests
        SET status = ${transition.requestStatus}
        WHERE id = ${String(current.request_id)}
        RETURNING *
      `;
      updatedRequest = rowObject(requestRows[0]);
    } else {
      const requestRows = await tx`
        SELECT *
        FROM public.hdc_service_requests
        WHERE id = ${String(current.request_id)}
        LIMIT 1
      `;
      updatedRequest = rowObject(requestRows[0]);
    }

    return {
      serviceTransaction: serviceTransactionView(rowObject(updatedRows[0])),
      updatedRequest: serviceRequestView(updatedRequest),
    };
  });

  await audit(sql, user.id, 'workflow.transaction.status', 'success', {
    transaction_id: transactionId,
    status: nextStatus,
  });
  return json(updated);
}

export default async (req: Request, _context: Context): Promise<Response> => {
  const path = new URL(req.url).pathname;
  if (path === '/api/health') {
    if (req.method !== 'GET') return methodNotAllowed();
    return json({ service: 'hdc-beta-api', status: 'ok' });
  }

  const isRolePath =
    path === '/api/roles/overview' ||
    path === '/api/role-applications';

  const isInternalPath =
    path === '/api/internal/dashboard' ||
    path === '/api/internal/role-applications' ||
    path.startsWith('/api/internal/role-applications/') ||
    path === '/api/internal/account-recovery' ||
    path.startsWith('/api/internal/account-recovery/');

  const isProfilePath =
    path === '/api/profiles' ||
    path === '/api/profiles/member' ||
    path.startsWith('/api/profiles/');

  if (path === '/api/auth/recovery/start') {
    return await handleRecoveryStart(req);
  }

  const sql = openDb();
  try {
    if (path === '/api/auth/register') return await handleRegister(req, sql);
    if (path === '/api/auth/login') return await handleLogin(req, sql);
    if (path === '/api/auth/session') return await handleSession(req, sql);
    if (path === '/api/auth/logout') return await handleLogout(req, sql);
    if (path === '/api/auth/recovery/verify') {
      return await handleRecoveryVerify(req, sql);
    }
    if (path === '/api/auth/recovery/reset') {
      return await handlePasswordReset(req, sql);
    }
    if (path === '/api/auth/password-reset/confirm') {
      return await handlePasswordReset(req, sql);
    }

    if (isProfilePath) {
      const session = await activeSession(req, sql);
      if (!session) return json({ error: 'unauthorized' }, 401);

      if (path === '/api/profiles') {
        return await handleProfilesOverview(req, sql, session.user);
      }
      if (path === '/api/profiles/member') {
        return await handleUpdateMemberProfile(req, sql, session.user);
      }

      const profileMatch = /^\/api\/profiles\/([^/]+)$/.exec(path);
      if (profileMatch) {
        return await handleUpdatePlatformRoleProfile(
          req,
          sql,
          session.user,
          profileMatch[1],
        );
      }
    }

    if (isInternalPath) {
      const session = await activeSession(req, sql);
      if (!session) return json({ error: 'unauthorized' }, 401);

      if (path === '/api/internal/dashboard') {
        return await handleInternalDashboard(req, sql, session.user);
      }
      if (path === '/api/internal/role-applications') {
        return await handleListRoleApplications(req, sql, session.user);
      }
      if (path === '/api/internal/account-recovery') {
        return await handleListRecoveryReviews(req, sql, session.user);
      }

      const roleApplicationMatch =
        /^\/api\/internal\/role-applications\/([^/]+)$/.exec(path);
      if (roleApplicationMatch) {
        return await handleReviewRoleApplication(
          req,
          sql,
          session.user,
          requirePathId(roleApplicationMatch[1]),
        );
      }

      const recoveryReviewMatch =
        /^\/api\/internal\/account-recovery\/([^/]+)$/.exec(path);
      if (recoveryReviewMatch) {
        return await handleReviewRecoveryRequest(
          req,
          sql,
          session.user,
          requirePathId(recoveryReviewMatch[1]),
        );
      }
    }

    if (isRolePath) {
      const session = await activeSession(req, sql);
      if (!session) return json({ error: 'unauthorized' }, 401);

      if (path === '/api/roles/overview') {
        return await handleRoleOverview(req, sql, session.user);
      }
      if (path === '/api/role-applications') {
        return await handleCreateRoleApplication(req, sql, session.user);
      }
    }

    const isWorkflowPath =
      path === '/api/workflow/bootstrap' ||
      path === '/api/service-requests' ||
      path.startsWith('/api/service-requests/') ||
      path === '/api/proposals' ||
      path.startsWith('/api/proposals/') ||
      path.startsWith('/api/service-transactions/');

    if (isWorkflowPath) {
      const session = await activeSession(req, sql);
      if (!session) return json({ error: 'unauthorized' }, 401);

      if (path === '/api/workflow/bootstrap') {
        return await handleWorkflowBootstrap(req, sql, session.user);
      }
      if (path === '/api/service-requests') {
        return await handleCreateServiceRequest(req, sql, session.user);
      }

      const serviceRequestMatch = /^\/api\/service-requests\/([^/]+)$/.exec(path);
      if (serviceRequestMatch) {
        const requestId = requirePathId(serviceRequestMatch[1]);
        if (req.method === 'PUT') {
          return await handleUpdateServiceRequest(req, sql, session.user, requestId);
        }
        if (req.method === 'DELETE') {
          return await handleDeleteServiceRequest(req, sql, session.user, requestId);
        }
        return methodNotAllowed();
      }

      if (path === '/api/proposals') {
        return await handleCreateProposal(req, sql, session.user);
      }

      const proposalAcceptMatch = /^\/api\/proposals\/([^/]+)\/accept$/.exec(path);
      if (proposalAcceptMatch) {
        return await handleAcceptProposal(
          req,
          sql,
          session.user,
          requirePathId(proposalAcceptMatch[1]),
        );
      }

      const proposalMatch = /^\/api\/proposals\/([^/]+)$/.exec(path);
      if (proposalMatch) {
        const proposalId = requirePathId(proposalMatch[1]);
        if (req.method === 'PUT') {
          return await handleUpdateProposal(req, sql, session.user, proposalId);
        }
        if (req.method === 'DELETE') {
          return await handleDeleteProposal(req, sql, session.user, proposalId);
        }
        return methodNotAllowed();
      }

      const transactionStatusMatch =
        /^\/api\/service-transactions\/([^/]+)\/status$/.exec(path);
      if (transactionStatusMatch) {
        return await handleTransactionStatus(
          req,
          sql,
          session.user,
          requirePathId(transactionStatusMatch[1]),
        );
      }
    }

    return json({ error: 'not_found' }, 404);
  } catch (error) {
    if (error instanceof WorkflowHttpError) {
      return json({ error: error.code, message: error.message }, error.statusCode);
    }

    const databaseCode = typeof error === 'object' && error !== null && 'code' in error
      ? String((error as { code?: unknown }).code ?? '')
      : '';
    if (databaseCode === '23505') {
      return json({
        error: isProfilePath ? 'profile_conflict' : 'workflow_conflict',
      }, 409);
    }
    if (databaseCode === '23503' || databaseCode === '23514') {
      return json({
        error: isProfilePath
          ? 'invalid_profile_relationship'
          : isInternalPath
            ? 'invalid_internal_relationship'
            : 'invalid_workflow_relationship',
      }, 409);
    }
    if (databaseCode === '42P01' || databaseCode === '42704') {
      return json({
        error: isProfilePath
          ? 'profile_backend_not_ready'
          : isInternalPath
            ? 'internal_backend_not_ready'
          : isRolePath
            ? 'role_backend_not_ready'
            : 'workflow_backend_not_ready',
      }, 503);
    }

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
    '/api/auth/recovery/start',
    '/api/auth/recovery/verify',
    '/api/auth/recovery/reset',
    '/api/auth/password-reset/confirm',
    '/api/roles/overview',
    '/api/role-applications',
    '/api/internal/dashboard',
    '/api/internal/role-applications',
    '/api/internal/role-applications/:id',
    '/api/internal/account-recovery',
    '/api/internal/account-recovery/:id',
    '/api/profiles',
    '/api/profiles/member',
    '/api/profiles/:role',
    '/api/workflow/bootstrap',
    '/api/service-requests',
    '/api/service-requests/:id',
    '/api/proposals',
    '/api/proposals/:id',
    '/api/proposals/:id/accept',
    '/api/service-transactions/:id/status',
  ],
};
