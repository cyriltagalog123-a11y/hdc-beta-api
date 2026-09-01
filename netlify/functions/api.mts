import type { Config, Context } from '@netlify/functions';
import bcrypt from 'bcryptjs';
import { createHmac, randomBytes, randomUUID } from 'node:crypto';
import type { DbClient, DbJsonValue } from './_lib/db.mjs';
import { checkDbReadiness, closeDb, openDb } from './_lib/db.mjs';
import { corsPreflightResponse, withCors } from './_lib/cors.mjs';
import { bearerToken, json, methodNotAllowed, readJson } from './_lib/http.mjs';
import {
  currentRecoveryPepper,
  identityFingerprintSecret,
  operationMode,
  recoveryPepperForKey,
  securityReviewEmail,
} from './_lib/env.mjs';
import { operationDecision } from '../../server/core/operation-mode.mjs';
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
  CURRENT_LEGAL_DOCUMENTS,
  CURRENT_LEGAL_VERSION,
  currentLegalDocumentList,
} from './_lib/legal-documents.mjs';
import {
  canTransitionProductListing,
  isProductListingStatus,
  parseProductListingWrite,
  parseProductPurchaseDecisionWrite,
  parseProductPurchaseRequestWrite,
  productListingView,
  productPurchaseRequestView,
  publicProductListingView,
  type SellingRoleCode,
} from './_lib/commerce.mjs';
import {
  normalizeMemberProfileWrite,
  normalizePlatformRoleProfileWrite,
} from './_lib/profiles.mjs';
import {
  PRIVATE_CONVERSATION_BETA_QUOTA_BYTES,
  assessPrivateMessage,
  parseConversationStorageMode,
  parsePrivateMessageWrite,
  privateConversationView,
  privateMessageStorageBytes,
} from './_lib/private-messaging.mjs';
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
  proposalWriteMatchesRow,
  proposalView,
  serviceRequestWriteMatchesRow,
  serviceRequestView,
  serviceTransactionView,
  technicianReputation,
  transactionSeedView,
  transactionTransition,
  type WorkflowUser,
} from './_lib/workflow.mjs';
import {
  changeOrderView,
  contentDigest,
  disputeEventView,
  disputeView,
  documentView,
  parseChangeOrderWrite,
  parseDisputeParticipantActionWrite,
  parseDisputeResolutionWrite,
  parseDisputeWrite,
  parseDocumentWrite,
  parseParticipantDecisionWrite,
  parsePaymentActionWrite,
  parsePaymentWrite,
  parseScheduleChangeWrite,
  parseTransactionExceptionWrite,
  paymentEventView,
  paymentView,
  receiptView,
  scheduleChangeView,
  targetStatusForDisputeOutcome,
  transactionExceptionView,
  utf8Bytes,
} from './_lib/transaction-tools.mjs';

const SESSION_DAYS = 7;
const LOGIN_FAILURE_LIMIT = 5;
const LOGIN_FAILURE_WINDOW_MINUTES = 15;
const RECOVERY_FAILURE_LIMIT = 5;
const RECOVERY_FAILURE_WINDOW_MINUTES = 60;
const RESET_TOKEN_MINUTES = 15;
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
  legalAcceptanceRequired: boolean;
  legalVersion: string;
  createdAt: string;
  updatedAt: string;
};

function identityFingerprint(email: string): string {
  return createHmac('sha256', identityFingerprintSecret())
    .update(email)
    .digest('hex');
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

async function notifyUser(
  sql: DbClient,
  userId: string,
  eventType: string,
  title: string,
  message: string,
  metadata: Record<string, string | number | boolean | null> = {},
  priority: 'normal' | 'high' | 'critical' = 'normal',
): Promise<void> {
  try {
    await sql`
      INSERT INTO public.hdc_notifications (
        user_id, event_type, priority, title, message, metadata
      ) VALUES (
        ${userId}, ${eventType}, ${priority}, ${title}, ${message},
        ${sql.json(metadata)}
      )
    `;
  } catch (error) {
    console.error(
      'HDC notification write failed',
      error instanceof Error ? error.message : 'unknown_error',
    );
  }
}

async function notifyTransactionCounterparty(
  sql: DbClient,
  transaction: Record<string, unknown>,
  actorId: string,
  eventType: string,
  title: string,
  message: string,
  metadata: Record<string, string | number | boolean | null> = {},
  priority: 'normal' | 'high' | 'critical' = 'normal',
): Promise<void> {
  const customerId = String(transaction.customer_id ?? transaction.customerId);
  const technicianId = String(
    transaction.technician_id ?? transaction.technicianId,
  );
  const recipientId = actorId === customerId ? technicianId : customerId;
  if (recipientId && recipientId !== actorId) {
    await notifyUser(
      sql,
      recipientId,
      eventType,
      title,
      message,
      metadata,
      priority,
    );
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
    WHERE user_id = ${userId}
      AND is_active = true
      AND status = 'active'
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

  const acceptanceRows = await sql`
    SELECT document_type, document_content_sha256
    FROM public.hdc_terms_acceptances
    WHERE user_id = ${userId}
      AND document_version = ${CURRENT_LEGAL_VERSION}
  `;
  const acceptedDocuments = new Map(
    acceptanceRows.map((row) => [
      String(row.document_type),
      String(row.document_content_sha256 ?? ''),
    ]),
  );
  const legalAcceptanceRequired = Object.values(CURRENT_LEGAL_DOCUMENTS)
    .some((document) =>
      acceptedDocuments.get(document.documentType) !== document.contentSha256,
    );

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
    legalAcceptanceRequired,
    legalVersion: CURRENT_LEGAL_VERSION,
    createdAt: new Date(String(user.created_at)).toISOString(),
    updatedAt: new Date(String(user.updated_at)).toISOString(),
  };
}

async function activeSession(
  req: Request,
  sql: DbClient,
  options: { allowPendingLegal?: boolean } = {},
): Promise<{ user: UserView; jti: string } | null> {
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
  if (user.legalAcceptanceRequired && options.allowPendingLegal !== true) {
    throw new WorkflowHttpError(
      'legal_acceptance_required',
      428,
      'Review and accept the current Terms of Service and Privacy Notice to continue.',
    );
  }

  if (operationMode() === 'normal') {
    await sql`
      UPDATE public.hdc_auth_sessions
      SET last_seen_at = now()
      WHERE user_id = ${verified.userId} AND token_jti = ${verified.jti}
    `;
  }

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
  const privacyAcknowledged = body.privacyAcknowledged === true;
  const termsVersion = typeof body.termsVersion === 'string'
    ? body.termsVersion.trim()
    : '';
  if (
    !email || !displayName || !password || !recoveryAnswers ||
    !termsAccepted || !privacyAcknowledged ||
    termsVersion !== CURRENT_LEGAL_VERSION
  ) {
    return json({
      error: 'invalid_registration',
      message: 'Complete the account details, all three recovery questions, the Terms acceptance, and the Privacy acknowledgement.',
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
            'registration', ${tx.json({ source: 'registration' })}
          ),
          (
            ${userId}, 'privacy_notice', ${termsVersion},
            ${CURRENT_LEGAL_DOCUMENTS.privacy_notice.contentSha256},
            'registration', ${tx.json({ source: 'registration' })}
          )
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
        SELECT question_code, answer_hash, pepper_key_id
        FROM public.hdc_account_recovery_answers
        WHERE user_id = ${userId}
          AND question_version = ${RECOVERY_QUESTION_VERSION}
      `
    : [];
  const storedAnswers = new Map(
    answerRows.map((row) => [String(row.question_code), {
      answerHash: String(row.answer_hash),
      pepperKeyId: String(row.pepper_key_id),
    }]),
  );
  const currentPepper = currentRecoveryPepper();
  const comparisons = await Promise.all(answers.map(async (item) => {
    const storedAnswer = storedAnswers.get(item.questionCode);
    const pepper = storedAnswer
      ? recoveryPepperForKey(storedAnswer.pepperKeyId)
      : null;
    const valid = await bcrypt.compare(
      recoveryAnswerDigest(
        item.answer,
        pepper?.secret ?? currentPepper.secret,
      ),
      storedAnswer?.answerHash ?? DUMMY_RECOVERY_HASH,
    );
    return Boolean(storedAnswer && pepper) && valid;
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

async function recentRecoveryAnswerUpdateFailures(
  sql: DbClient,
  userId: string,
): Promise<number> {
  const rows = await sql`
    SELECT count(*)::int AS failures
    FROM public.hdc_security_audit
    WHERE user_id = ${userId}
      AND event_type = 'auth.recovery.answers_update'
      AND event_status IN ('failed', 'blocked')
      AND created_at > now() -
        (${LOGIN_FAILURE_WINDOW_MINUTES} * interval '1 minute')
  `;
  return Number(rows[0]?.failures ?? 0);
}

/**
 * Lets authenticated members created before Build 12 add recovery answers,
 * and lets every member replace them after confirming the current password.
 * Plaintext answers never leave this request handler or enter the audit log.
 */
async function handleUpdateRecoveryAnswers(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);

  const currentPassword = typeof body.currentPassword === 'string'
    ? body.currentPassword
    : '';
  const recoveryAnswers = parseRecoveryAnswers(body.recoveryAnswers);
  if (
    currentPassword.length < 1 || currentPassword.length > 128 ||
    !recoveryAnswers
  ) {
    return json({
      error: 'invalid_recovery_answers',
      message: 'Enter your current password and three distinct recovery answers.',
    }, 400);
  }

  if (
    await recentRecoveryAnswerUpdateFailures(sql, user.id) >=
      LOGIN_FAILURE_LIMIT
  ) {
    await audit(sql, user.id, 'auth.recovery.answers_update', 'blocked', {
      reason: 'rate_limit',
    });
    return json({
      error: 'too_many_attempts',
      message: 'Security updates are temporarily limited. Try again later.',
    }, 429);
  }

  const passwordRows = await sql`
    SELECT password_hash
    FROM public.hdc_users
    WHERE id = ${user.id} AND status = 'active'
    LIMIT 1
  `;
  const validPassword = passwordRows.length > 0 && await bcrypt.compare(
    currentPassword,
    String(passwordRows[0].password_hash),
  );
  if (!validPassword) {
    await audit(sql, user.id, 'auth.recovery.answers_update', 'failed', {
      reason: 'invalid_current_password',
    });
    return json({
      error: 'invalid_current_password',
      message: 'The current password is incorrect.',
    }, 401);
  }

  const prohibitedAnswers = new Set([
    normalizeRecoveryAnswer(user.email),
    normalizeRecoveryAnswer(user.displayName),
    normalizeRecoveryAnswer(currentPassword),
  ].filter((value): value is string => value !== null));
  if (recoveryAnswers.some((item) => prohibitedAnswers.has(item.answer))) {
    return json({
      error: 'weak_recovery_answers',
      message: 'Recovery answers must not repeat your email, name, or password.',
    }, 400);
  }

  const pepper = currentRecoveryPepper();
  const recoveryHashes = await Promise.all(recoveryAnswers.map(async (item) => ({
    questionCode: item.questionCode,
    pepperKeyId: pepper.keyId,
    answerHash: await bcrypt.hash(
      recoveryAnswerDigest(item.answer, pepper.secret),
      12,
    ),
  })));

  await sql.begin(async (tx) => {
    for (const item of recoveryHashes) {
      await tx`
        INSERT INTO public.hdc_account_recovery_answers (
          user_id, question_version, question_code, pepper_key_id, answer_hash
        ) VALUES (
          ${user.id}, ${RECOVERY_QUESTION_VERSION},
          ${item.questionCode}, ${item.pepperKeyId}, ${item.answerHash}
        )
        ON CONFLICT (user_id, question_code)
        DO UPDATE SET
          question_version = EXCLUDED.question_version,
          pepper_key_id = EXCLUDED.pepper_key_id,
          answer_hash = EXCLUDED.answer_hash
      `;
    }
    await tx`
      UPDATE public.hdc_password_reset_tokens
      SET status = 'revoked', consumed_at = COALESCE(consumed_at, now())
      WHERE user_id = ${user.id} AND status = 'pending'
    `;
    await tx`
      UPDATE public.hdc_account_recovery_review_requests
      SET status = 'cancelled', delivery_status = 'not_required'
      WHERE user_id = ${user.id} AND status = 'pending'
    `;
  });

  await audit(sql, user.id, 'auth.recovery.answers_update', 'success', {
    question_version: RECOVERY_QUESTION_VERSION,
    reset_tokens_revoked: true,
  });
  return json({ success: true });
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
  const session = await activeSession(req, sql, { allowPendingLegal: true });
  if (!session) return json({ error: 'unauthorized' }, 401);
  return json({ user: session.user });
}

async function handleLegalDocuments(req: Request): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  return json({
    version: CURRENT_LEGAL_VERSION,
    documents: currentLegalDocumentList(),
  });
}

async function handleLegalAcceptance(
  req: Request,
  sql: DbClient,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const session = await activeSession(req, sql, { allowPendingLegal: true });
  if (!session) return json({ error: 'unauthorized' }, 401);

  const body = await readJson(req);
  if (
    !body ||
    body.version !== CURRENT_LEGAL_VERSION ||
    body.termsAccepted !== true ||
    body.privacyAcknowledged !== true
  ) {
    return json({
      error: 'invalid_legal_acceptance',
      message: 'Review and acknowledge both current legal documents.',
    }, 400);
  }

  const userAgent = (req.headers.get('user-agent') ?? '').slice(0, 500);
  await sql.begin(async (tx) => {
    await tx`
      INSERT INTO public.hdc_terms_acceptances (
        user_id, document_type, document_version,
        document_content_sha256, acceptance_method, client_metadata
      ) VALUES
        (
          ${session.user.id}, 'terms_of_service', ${CURRENT_LEGAL_VERSION},
          ${CURRENT_LEGAL_DOCUMENTS.terms_of_service.contentSha256},
          'renewal', ${tx.json({ source: 'legal_gate', userAgent })}
        ),
        (
          ${session.user.id}, 'privacy_notice', ${CURRENT_LEGAL_VERSION},
          ${CURRENT_LEGAL_DOCUMENTS.privacy_notice.contentSha256},
          'renewal', ${tx.json({ source: 'legal_gate', userAgent })}
        )
      ON CONFLICT (user_id, document_type, document_version) DO NOTHING
    `;
  });

  const user = await getUserView(sql, session.user.id);
  if (!user || user.legalAcceptanceRequired) {
    throw new WorkflowHttpError(
      'legal_acceptance_conflict',
      409,
      'The legal acceptance record could not be verified. Contact HDC support.',
    );
  }
  await audit(sql, user.id, 'legal.acceptance', 'success', {
    version: CURRENT_LEGAL_VERSION,
    terms_sha256: CURRENT_LEGAL_DOCUMENTS.terms_of_service.contentSha256,
    privacy_sha256: CURRENT_LEGAL_DOCUMENTS.privacy_notice.contentSha256,
  });
  return json({ user });
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

async function handleNotificationCenter(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  const rows = await sql`
    SELECT *
    FROM public.hdc_notifications
    WHERE user_id = ${user.id}
    ORDER BY created_at DESC
    LIMIT 100
  `;
  const unreadRows = await sql`
    SELECT count(*)::int AS unread_count
    FROM public.hdc_notifications
    WHERE user_id = ${user.id}
      AND read_at IS NULL
  `;
  return json({
    notifications: rows.map((row) => roleNotificationView(rowObject(row))),
    unreadCount: Number(unreadRows[0]?.unread_count ?? 0),
    updatedAt: new Date().toISOString(),
  });
}

async function handleNotificationRead(
  req: Request,
  sql: DbClient,
  user: UserView,
  notificationId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const rows = await sql`
    UPDATE public.hdc_notifications
    SET read_at = COALESCE(read_at, now())
    WHERE id::text = ${notificationId}
      AND user_id = ${user.id}
    RETURNING *
  `;
  if (rows.length === 0) {
    throw new WorkflowHttpError(
      'notification_not_found',
      404,
      'That notification was not found.',
    );
  }
  return json({ notification: roleNotificationView(rowObject(rows[0])) });
}

async function handleNotificationsReadAll(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const rows = await sql`
    UPDATE public.hdc_notifications
    SET read_at = COALESCE(read_at, now())
    WHERE user_id = ${user.id}
      AND read_at IS NULL
    RETURNING id
  `;
  return json({ updated: rows.length });
}

const PRIVACY_REQUEST_TYPES = new Set([
  'access',
  'correction',
  'objection',
  'export',
  'deletion',
  'complaint',
  'other',
]);

const PRIVACY_REQUEST_TRANSITIONS: Record<string, ReadonlySet<string>> = {
  submitted: new Set(['acknowledged', 'in_review']),
  acknowledged: new Set(['in_review', 'resolved', 'rejected']),
  in_review: new Set(['resolved', 'rejected']),
  resolved: new Set(),
  rejected: new Set(),
};

function privacyRequestView(row: Record<string, unknown>): Record<string, unknown> {
  const view: Record<string, unknown> = {
    id: String(row.id),
    publicReference: String(row.public_reference),
    userId: String(row.user_id),
    requestType: String(row.request_type),
    details: String(row.details),
    status: String(row.status),
    version: Number(row.version),
    reviewerNote: String(row.reviewer_note ?? ''),
    acknowledgedAt: row.acknowledged_at
      ? new Date(String(row.acknowledged_at)).toISOString()
      : null,
    resolvedAt: row.resolved_at
      ? new Date(String(row.resolved_at)).toISOString()
      : null,
    createdAt: new Date(String(row.created_at)).toISOString(),
    updatedAt: new Date(String(row.updated_at)).toISOString(),
  };
  if (row.display_name) view.displayName = String(row.display_name);
  if (row.email) view.email = String(row.email);
  return view;
}

async function notifyPrivacyReviewers(
  sql: DbClient,
  publicReference: string,
  requestType: string,
): Promise<void> {
  const reviewers = await sql`
    SELECT DISTINCT user_id
    FROM public.hdc_internal_role_assignments
    WHERE is_active = true
      AND role IN ('owner', 'super_admin')
  `;
  for (const reviewer of reviewers) {
    await notifyUser(
      sql,
      String(reviewer.user_id),
      'privacy.request_submitted',
      'Privacy request submitted',
      `${publicReference} requires private review.`,
      { publicReference, requestType },
      'high',
    );
  }
}

async function handlePrivacyRequests(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method === 'GET') {
    const rows = await withWorkflowAuthority(sql, user, async (tx) => await tx`
      SELECT *
      FROM public.hdc_privacy_requests
      WHERE user_id = ${user.id}
      ORDER BY created_at DESC
      LIMIT 100
    `);
    return json({
      requests: rows.map((row) => privacyRequestView(rowObject(row))),
      updatedAt: new Date().toISOString(),
    });
  }
  if (req.method !== 'POST') return methodNotAllowed();

  const body = await readJson(req);
  const requestType = typeof body?.requestType === 'string'
    ? body.requestType.trim()
    : '';
  const details = typeof body?.details === 'string' ? body.details.trim() : '';
  if (!PRIVACY_REQUEST_TYPES.has(requestType) || details.length < 10 || details.length > 4000) {
    return json({
      error: 'invalid_privacy_request',
      message: 'Choose a request type and provide 10 to 4,000 characters of detail.',
    }, 400);
  }

  const rows = await withWorkflowAuthority(sql, user, async (tx) => await tx`
    INSERT INTO public.hdc_privacy_requests (user_id, request_type, details)
    VALUES (${user.id}, ${requestType}, ${details})
    RETURNING *
  `);
  const requestView = privacyRequestView(rowObject(rows[0]));
  const publicReference = String(requestView.publicReference);
  await audit(sql, user.id, 'privacy.request.submit', 'success', {
    public_reference: publicReference,
    request_type: requestType,
  });
  await notifyPrivacyReviewers(sql, publicReference, requestType);
  return json({ request: requestView }, 201);
}

async function handleInternalPrivacyRequests(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  requireDisputeResolver(user);
  const rows = await sql`
    SELECT privacy_request.*, account.display_name, account.email::text AS email
    FROM public.hdc_privacy_requests privacy_request
    JOIN public.hdc_users account ON account.id = privacy_request.user_id
    ORDER BY
      CASE privacy_request.status
        WHEN 'submitted' THEN 0
        WHEN 'acknowledged' THEN 1
        WHEN 'in_review' THEN 2
        ELSE 3
      END,
      privacy_request.created_at DESC
    LIMIT 200
  `;
  return json({
    requests: rows.map((row) => privacyRequestView(rowObject(row))),
    updatedAt: new Date().toISOString(),
  });
}

async function handleInternalPrivacyRequestReview(
  req: Request,
  sql: DbClient,
  user: UserView,
  requestId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  requireDisputeResolver(user);
  const body = await readJson(req);
  const status = typeof body?.status === 'string' ? body.status.trim() : '';
  const reviewerNote = typeof body?.reviewerNote === 'string'
    ? body.reviewerNote.trim()
    : '';
  const expectedVersion = Number(body?.version);
  if (
    !Number.isInteger(expectedVersion) || expectedVersion < 1 ||
    !Object.hasOwn(PRIVACY_REQUEST_TRANSITIONS, status) ||
    reviewerNote.length > 4000
  ) {
    return json({ error: 'invalid_privacy_review' }, 400);
  }

  const updated = await sql.begin(async (tx) => {
    const rows = await tx`
      SELECT * FROM public.hdc_privacy_requests
      WHERE id = ${requestId}
      FOR UPDATE
    `;
    if (rows.length === 0) {
      throw new WorkflowHttpError(
        'privacy_request_not_found', 404, 'That privacy request was not found.',
      );
    }
    const current = rowObject(rows[0]);
    const currentStatus = String(current.status);
    if (Number(current.version) !== expectedVersion) {
      throw new WorkflowHttpError(
        'privacy_request_changed', 409, 'This request changed. Refresh before reviewing it.',
      );
    }
    if (!PRIVACY_REQUEST_TRANSITIONS[currentStatus]?.has(status)) {
      throw new WorkflowHttpError(
        'invalid_privacy_transition', 409, 'That privacy request status transition is not allowed.',
      );
    }
    const result = await tx`
      UPDATE public.hdc_privacy_requests
      SET status = ${status},
          version = version + 1,
          reviewer_note = ${reviewerNote},
          reviewed_by = ${user.id},
          acknowledged_at = CASE
            WHEN ${status} IN ('acknowledged', 'in_review', 'resolved', 'rejected')
              THEN COALESCE(acknowledged_at, now())
            ELSE acknowledged_at
          END,
          resolved_at = CASE
            WHEN ${status} IN ('resolved', 'rejected') THEN now()
            ELSE NULL
          END
      WHERE id = ${requestId}
      RETURNING *
    `;
    return rowObject(result[0]);
  });

  await audit(sql, user.id, 'privacy.request.review', 'success', {
    public_reference: String(updated.public_reference),
    status,
  });
  await notifyUser(
    sql,
    String(updated.user_id),
    'privacy.request_updated',
    'Privacy request updated',
    `${String(updated.public_reference)} is now ${status.replace('_', ' ')}.`,
    { publicReference: String(updated.public_reference), status },
    status === 'rejected' ? 'high' : 'normal',
  );
  return json({ request: privacyRequestView(updated) });
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

function technicianDirectoryEntryView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  const details = row.details && typeof row.details === 'object' &&
      !Array.isArray(row.details)
    ? row.details
    : {};
  return {
    profileId: String(row.id),
    publicMemberId: String(row.public_member_id),
    publicName: String(row.public_name),
    headline: String(row.headline ?? ''),
    description: String(row.description ?? ''),
    location: String(row.location ?? ''),
    contactEmail: String(row.contact_email ?? ''),
    contactPhone: String(row.contact_phone ?? ''),
    website: String(row.website ?? ''),
    details,
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
      AND assignment.status = 'active'
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

async function handleTechnicianDirectory(
  req: Request,
  sql: DbClient,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();

  const rows = await sql`
    SELECT
      profile.*,
      member.public_member_id
    FROM public.hdc_platform_role_profiles profile
    JOIN public.hdc_users member
      ON member.id = profile.user_id
      AND member.status = 'active'
    JOIN public.hdc_user_roles assignment
      ON assignment.user_id = profile.user_id
      AND assignment.role::text = 'technician'
      AND assignment.is_active = true
      AND assignment.status = 'active'
    WHERE profile.role = 'technician'
      AND profile.is_public = true
    ORDER BY
      CASE WHEN profile.location = '' THEN 1 ELSE 0 END,
      profile.updated_at DESC,
      profile.public_name ASC
  `;

  return json({
    technicians: rows.map((row) =>
      technicianDirectoryEntryView(rowObject(row))),
    updatedAt: new Date().toISOString(),
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

  if (permissions.canApprovePlatformRoles) {
    const rows = await sql`
      SELECT count(*)::int AS pending_count
      FROM public.hdc_service_disputes
      WHERE status IN ('open', 'underReview')
    `;
    statistics.pendingDisputes = Number(rows[0]?.pending_count ?? 0);
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

async function activeSellingProfile(
  sql: DbClient,
  userId: string,
  role: SellingRoleCode,
): Promise<Record<string, unknown> | null> {
  const rows = await sql`
    SELECT profile.id, profile.role, profile.public_name
    FROM public.hdc_platform_role_profiles profile
    JOIN public.hdc_user_roles assignment
      ON assignment.user_id = profile.user_id
     AND assignment.role::text = profile.role
    WHERE profile.user_id = ${userId}
      AND profile.role = ${role}
      AND assignment.is_active = true
      AND assignment.status = 'active'
      AND assignment.role::text IN ('seller', 'supplier', 'store')
    LIMIT 1
  `;
  return rows.length === 0 ? null : rowObject(rows[0]);
}

async function handleProductCatalog(
  req: Request,
  sql: DbClient,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  const rows = await sql`
    SELECT listing.*, profile.public_name AS seller_public_name
    FROM public.hdc_product_listings listing
    JOIN public.hdc_platform_role_profiles profile
      ON profile.id = listing.seller_profile_id
     AND profile.user_id = listing.seller_user_id
     AND profile.role = listing.seller_role
    JOIN public.hdc_user_roles assignment
      ON assignment.user_id = listing.seller_user_id
     AND assignment.role::text = listing.seller_role
     AND assignment.is_active = true
     AND assignment.status = 'active'
    WHERE listing.status = 'active'
      AND listing.stock_quantity > 0
      AND listing.published_at IS NOT NULL
    ORDER BY listing.updated_at DESC
    LIMIT 500
  `;
  return json({
    listings: rows.map((row) => publicProductListingView(rowObject(row))),
    returned: rows.length,
    limit: 500,
  });
}

async function handleBuyerDashboard(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  const rows = await sql`
    SELECT *
    FROM public.hdc_product_purchase_requests
    WHERE buyer_user_id = ${user.id}
    ORDER BY submitted_at DESC
    LIMIT 500
  `;
  return json({
    purchaseRequests: rows.map((row) =>
      productPurchaseRequestView(rowObject(row))),
  });
}

async function handleCreateProductPurchaseRequest(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  if (!user.platformRoles.includes('customer')) {
    throw new WorkflowHttpError(
      'customer_role_required',
      403,
      'An active HDC Customer workspace is required to request a purchase.',
    );
  }
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const write = parseProductPurchaseRequestWrite(body);
  if (!write) {
    return json({
      error: 'invalid_purchase_request',
      message: 'Choose an available quantity and check the buyer note.',
    }, 400);
  }

  const result = await sql.begin(async (tx) => {
    const retryRows = await tx`
      SELECT *
      FROM public.hdc_product_purchase_requests
      WHERE buyer_user_id = ${user.id}
        AND idempotency_key = ${write.clientRequestId}
      LIMIT 1
    `;
    if (retryRows.length > 0) {
      return { request: rowObject(retryRows[0]), created: false };
    }

    const recentRows = await tx`
      SELECT count(*)::int AS request_count
      FROM public.hdc_product_purchase_requests
      WHERE buyer_user_id = ${user.id}
        AND submitted_at >= now() - interval '1 hour'
    `;
    if (Number(recentRows[0]?.request_count ?? 0) >= 50) {
      throw new WorkflowHttpError(
        'purchase_request_rate_limited',
        429,
        'Too many purchase requests were submitted recently. Try again later.',
      );
    }

    const listingRows = await tx`
      SELECT listing.*, profile.public_name AS seller_public_name
      FROM public.hdc_product_listings listing
      JOIN public.hdc_platform_role_profiles profile
        ON profile.id = listing.seller_profile_id
       AND profile.user_id = listing.seller_user_id
       AND profile.role = listing.seller_role
      JOIN public.hdc_user_roles assignment
        ON assignment.user_id = listing.seller_user_id
       AND assignment.role::text = listing.seller_role
       AND assignment.is_active = true
       AND assignment.status = 'active'
      WHERE listing.id = ${write.listingId}
        AND listing.status = 'active'
        AND listing.stock_quantity >= ${write.quantity}
      FOR UPDATE OF listing
    `;
    if (listingRows.length === 0) {
      throw new WorkflowHttpError(
        'product_listing_unavailable',
        409,
        'That item or requested quantity is no longer available.',
      );
    }
    const listing = rowObject(listingRows[0]);
    if (String(listing.seller_user_id) === user.id) {
      throw new WorkflowHttpError(
        'self_purchase_not_allowed',
        409,
        'An account cannot request a purchase from its own listing.',
      );
    }

    const subtotal = Number(listing.unit_price_minor) * write.quantity;
    const insertedRows = await tx`
      INSERT INTO public.hdc_product_purchase_requests (
        idempotency_key, listing_id, seller_user_id, seller_role,
        buyer_user_id, public_listing_id_snapshot, listing_title_snapshot,
        seller_name_snapshot, buyer_name_snapshot,
        buyer_public_member_id_snapshot, quantity, currency,
        unit_price_minor, subtotal_minor, buyer_note
      ) VALUES (
        ${write.clientRequestId}, ${write.listingId},
        ${String(listing.seller_user_id)}, ${String(listing.seller_role)},
        ${user.id}, ${String(listing.public_listing_id)},
        ${String(listing.title)}, ${String(listing.seller_public_name)},
        ${user.displayName}, ${user.publicMemberId}, ${write.quantity},
        ${String(listing.currency)}, ${Number(listing.unit_price_minor)},
        ${subtotal}, ${write.buyerNote}
      )
      ON CONFLICT DO NOTHING
      RETURNING *
    `;

    if (insertedRows.length === 0) {
      const concurrentRetryRows = await tx`
        SELECT *
        FROM public.hdc_product_purchase_requests
        WHERE buyer_user_id = ${user.id}
          AND idempotency_key = ${write.clientRequestId}
        LIMIT 1
      `;
      if (concurrentRetryRows.length > 0) {
        return { request: rowObject(concurrentRetryRows[0]), created: false };
      }
      const pendingRows = await tx`
        SELECT id
        FROM public.hdc_product_purchase_requests
        WHERE buyer_user_id = ${user.id}
          AND listing_id = ${write.listingId}
          AND status = 'submitted'
        LIMIT 1
      `;
      if (pendingRows.length > 0) {
        throw new WorkflowHttpError(
          'purchase_request_pending',
          409,
          'You already have a pending purchase request for this listing.',
        );
      }
      throw new WorkflowHttpError(
        'commerce_conflict',
        409,
        'The purchase request conflicted with a newer marketplace change.',
      );
    }

    const created = rowObject(insertedRows[0]);
    await tx`
      INSERT INTO public.hdc_product_purchase_request_events (
        purchase_request_id, actor_user_id, event_type,
        from_status, to_status, snapshot
      ) VALUES (
        ${String(created.id)}, ${user.id}, 'submitted', NULL, 'submitted',
        ${tx.json({
          publicPurchaseId: String(created.public_purchase_id),
          publicListingId: String(created.public_listing_id_snapshot),
          quantity: Number(created.quantity),
          subtotalMinor: Number(created.subtotal_minor),
        })}
      )
    `;
    return { request: created, created: true };
  });

  await audit(sql, user.id, 'commerce.purchase_request.submit', 'success', {
    purchase_request_id: String(result.request.id),
    listing_id: String(result.request.listing_id),
    created: result.created,
  });
  return json(
    { purchaseRequest: productPurchaseRequestView(result.request) },
    result.created ? 201 : 200,
  );
}

async function handleProductPurchaseRequestAction(
  req: Request,
  sql: DbClient,
  user: UserView,
  purchaseRequestId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const write = parseProductPurchaseDecisionWrite(body);
  if (!write) return json({ error: 'invalid_purchase_request_action' }, 400);

  const updated = await sql.begin(async (tx) => {
    const lookupRows = await tx`
      SELECT *
      FROM public.hdc_product_purchase_requests
      WHERE id = ${purchaseRequestId}
    `;
    if (lookupRows.length === 0) {
      throw new WorkflowHttpError(
        'purchase_request_not_found',
        404,
        'The purchase request was not found.',
      );
    }
    const lookup = rowObject(lookupRows[0]);
    const isBuyer = String(lookup.buyer_user_id) === user.id;
    const isSeller = String(lookup.seller_user_id) === user.id;
    if ((write.action === 'cancel' && !isBuyer) ||
        (write.action !== 'cancel' && !isSeller)) {
      throw new WorkflowHttpError(
        'purchase_request_not_found',
        404,
        'The purchase request was not found.',
      );
    }
    if (String(lookup.status) !== 'submitted') {
      throw new WorkflowHttpError(
        'purchase_request_already_decided',
        409,
        'That purchase request is no longer pending.',
      );
    }

    const nextStatus = write.action === 'accept'
      ? 'accepted'
      : write.action === 'decline'
        ? 'declined'
        : 'cancelled';

    let listing: Record<string, unknown> | null = null;
    if (write.action === 'accept') {
      const listingRows = await tx`
        SELECT *
        FROM public.hdc_product_listings
        WHERE id = ${String(lookup.listing_id)}
          AND seller_user_id = ${user.id}
        FOR UPDATE
      `;
      if (listingRows.length === 0) {
        throw new WorkflowHttpError(
          'product_listing_unavailable',
          409,
          'The related product listing is no longer available.',
        );
      }
      listing = rowObject(listingRows[0]);
      const role = String(listing.seller_role);
      if (role !== 'seller' && role !== 'supplier' && role !== 'store') {
        throw new Error('Invalid stored HDC selling role.');
      }
      const profile = await activeSellingProfile(
        tx as unknown as DbClient,
        user.id,
        role,
      );
      if (!profile) {
        throw new WorkflowHttpError(
          'selling_role_required',
          403,
          'An active selling workspace is required to accept this request.',
        );
      }
    }

    // Acceptance locks the listing before the request. Listing-close triggers
    // use that same order, preventing a listing/order deadlock. Buyer cancel
    // and seller decline need only the request lock.
    const currentRows = await tx`
      SELECT *
      FROM public.hdc_product_purchase_requests
      WHERE id = ${purchaseRequestId}
      FOR UPDATE
    `;
    if (currentRows.length === 0) {
      throw new WorkflowHttpError(
        'purchase_request_not_found',
        404,
        'The purchase request was not found.',
      );
    }
    const current = rowObject(currentRows[0]);
    const stillBuyer = String(current.buyer_user_id) === user.id;
    const stillSeller = String(current.seller_user_id) === user.id;
    if ((write.action === 'cancel' && !stillBuyer) ||
        (write.action !== 'cancel' && !stillSeller)) {
      throw new WorkflowHttpError(
        'purchase_request_not_found',
        404,
        'The purchase request was not found.',
      );
    }
    if (Number(current.version) !== write.version) {
      throw new WorkflowHttpError(
        'purchase_request_conflict',
        409,
        'The purchase request changed elsewhere. Refresh and try again.',
      );
    }
    if (String(current.status) !== 'submitted') {
      throw new WorkflowHttpError(
        'purchase_request_already_decided',
        409,
        'That purchase request is no longer pending.',
      );
    }
    if (write.action === 'accept' && listing) {
      if (String(current.listing_id) !== String(listing.id) ||
          String(current.seller_role) !== String(listing.seller_role)) {
        throw new WorkflowHttpError(
          'purchase_request_conflict',
          409,
          'The purchase request changed elsewhere. Refresh and try again.',
        );
      }
      const quantity = Number(current.quantity);
      if (String(listing.status) !== 'active' ||
          Number(listing.stock_quantity) < quantity) {
        throw new WorkflowHttpError(
          'product_listing_unavailable',
          409,
          'There is not enough active stock to accept this request.',
        );
      }
    }

    const requestRows = await tx`
      UPDATE public.hdc_product_purchase_requests
      SET status = ${nextStatus},
          seller_note = CASE
            WHEN ${nextStatus} IN ('accepted', 'declined') THEN ${write.note}
            ELSE seller_note
          END,
          decided_at = CASE
            WHEN ${nextStatus} IN ('accepted', 'declined') THEN now()
            ELSE NULL
          END,
          cancelled_at = CASE
            WHEN ${nextStatus} = 'cancelled' THEN now()
            ELSE NULL
          END
      WHERE id = ${purchaseRequestId}
      RETURNING *
    `;
    const requestRow = rowObject(requestRows[0]);

    if (write.action === 'accept' && listing) {
      const quantity = Number(current.quantity);
      const remainingStock = Number(listing.stock_quantity) - quantity;
      const nextListingStatus = remainingStock === 0 ? 'sold' : 'active';
      const listingRows = await tx`
        UPDATE public.hdc_product_listings
        SET stock_quantity = ${remainingStock},
            status = ${nextListingStatus},
            sold_at = CASE
              WHEN ${nextListingStatus} = 'sold' THEN now()
              ELSE NULL
            END
        WHERE id = ${String(current.listing_id)}
          AND seller_user_id = ${user.id}
        RETURNING *
      `;
      const listingRow = rowObject(listingRows[0]);
      await tx`
        INSERT INTO public.hdc_product_listing_events (
          listing_id, actor_user_id, event_type,
          from_status, to_status, snapshot
        ) VALUES (
          ${String(current.listing_id)}, ${user.id},
          ${nextListingStatus === 'sold' ? 'status_changed' : 'updated'},
          'active', ${nextListingStatus},
          ${tx.json({
            reason: 'purchase_request_accepted',
            publicPurchaseId: String(current.public_purchase_id),
            quantity,
            remainingStock,
            version: Number(listingRow.version),
          })}
        )
      `;
    }

    await tx`
      INSERT INTO public.hdc_product_purchase_request_events (
        purchase_request_id, actor_user_id, event_type,
        from_status, to_status, snapshot
      ) VALUES (
        ${purchaseRequestId}, ${user.id}, ${nextStatus},
        'submitted', ${nextStatus},
        ${tx.json({ note: write.note })}
      )
    `;
    return requestRow;
  });

  await audit(sql, user.id, 'commerce.purchase_request.status', 'success', {
    purchase_request_id: purchaseRequestId,
    status: String(updated.status),
  });
  return json({ purchaseRequest: productPurchaseRequestView(updated) });
}

async function handleSellerDashboard(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();

  const profiles = await sql`
    SELECT profile.id, profile.role, profile.public_name
    FROM public.hdc_platform_role_profiles profile
    JOIN public.hdc_user_roles assignment
      ON assignment.user_id = profile.user_id
     AND assignment.role::text = profile.role
    WHERE profile.user_id = ${user.id}
      AND profile.role IN ('seller', 'supplier', 'store')
      AND assignment.is_active = true
      AND assignment.status = 'active'
    ORDER BY profile.role
  `;
  const listings = await sql`
    SELECT *
    FROM public.hdc_product_listings
    WHERE seller_user_id = ${user.id}
    ORDER BY
      CASE status
        WHEN 'active' THEN 1
        WHEN 'draft' THEN 2
        WHEN 'paused' THEN 3
        WHEN 'sold' THEN 4
        ELSE 5
      END,
      updated_at DESC
    LIMIT 500
  `;
  const summaryRows = await sql`
    SELECT
      (count(*) FILTER (WHERE status = 'active'))::int
        AS active_listings,
      (count(*) FILTER (WHERE status = 'draft'))::int
        AS draft_listings,
      (count(*) FILTER (WHERE status = 'paused'))::int
        AS paused_listings,
      (count(*) FILTER (WHERE status = 'sold'))::int
        AS sold_listings,
      (count(*) FILTER (
        WHERE status = 'active' AND stock_quantity BETWEEN 1 AND 3
      ))::int AS low_stock_listings
    FROM public.hdc_product_listings
    WHERE seller_user_id = ${user.id}
  `;
  const purchaseRequests = await sql`
    SELECT *
    FROM public.hdc_product_purchase_requests
    WHERE seller_user_id = ${user.id}
    ORDER BY
      CASE status
        WHEN 'submitted' THEN 1
        WHEN 'accepted' THEN 2
        WHEN 'declined' THEN 3
        ELSE 4
      END,
      submitted_at DESC
    LIMIT 500
  `;
  const purchaseSummaryRows = await sql`
    SELECT (count(*) FILTER (WHERE status = 'submitted'))::int
      AS pending_purchase_requests
    FROM public.hdc_product_purchase_requests
    WHERE seller_user_id = ${user.id}
  `;
  const views = listings.map((row) => productListingView(rowObject(row)));
  const summary = rowObject(summaryRows[0]);
  const purchaseSummary = rowObject(purchaseSummaryRows[0]);

  return json({
    canSell: profiles.length > 0,
    sellingProfiles: profiles.map((row) => ({
      profileId: String(row.id),
      role: String(row.role),
      publicName: String(row.public_name),
    })),
    summary: {
      activeListings: Number(summary.active_listings),
      draftListings: Number(summary.draft_listings),
      pausedListings: Number(summary.paused_listings),
      soldListings: Number(summary.sold_listings),
      lowStockListings: Number(summary.low_stock_listings),
      pendingPurchaseRequests:
        Number(purchaseSummary.pending_purchase_requests),
    },
    listings: views,
    purchaseRequests: purchaseRequests.map((row) =>
      productPurchaseRequestView(rowObject(row))),
  });
}

async function handleCreateProductListing(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const write = parseProductListingWrite(body);
  if (
    !write || write.version !== null ||
    (write.status !== 'draft' && write.status !== 'active')
  ) {
    return json({
      error: 'invalid_product_listing',
      message: 'Complete the required technology item fields and save it as a draft or active listing.',
    }, 400);
  }

  const listing = await sql.begin(async (tx) => {
    const profile = await activeSellingProfile(
      tx as unknown as DbClient,
      user.id,
      write.sellerRole,
    );
    if (!profile) {
      throw new WorkflowHttpError(
        'selling_role_required',
        403,
        'An approved Seller, Supplier, or Store profile is required.',
      );
    }

    const rows = await tx`
      INSERT INTO public.hdc_product_listings (
        seller_profile_id, seller_user_id, seller_role, category_code,
        title, description, item_condition, currency, unit_price_minor,
        stock_quantity, status, published_at
      ) VALUES (
        ${String(profile.id)}, ${user.id}, ${write.sellerRole},
        ${write.categoryCode}, ${write.title}, ${write.description},
        ${write.condition}, ${write.currency}, ${write.unitPriceMinor},
        ${write.stockQuantity}, ${write.status},
        CASE WHEN ${write.status} = 'active' THEN now() ELSE NULL END
      )
      RETURNING *
    `;
    const created = rowObject(rows[0]);
    await tx`
      INSERT INTO public.hdc_product_listing_events (
        listing_id, actor_user_id, event_type, from_status, to_status, snapshot
      ) VALUES (
        ${String(created.id)}, ${user.id}, 'created', NULL,
        ${write.status},
        ${tx.json({
          publicListingId: String(created.public_listing_id),
          sellerRole: write.sellerRole,
          categoryCode: write.categoryCode,
          stockQuantity: write.stockQuantity,
        })}
      )
    `;
    return created;
  });

  await audit(sql, user.id, 'commerce.listing.create', 'success', {
    listing_id: String(listing.id),
    public_listing_id: String(listing.public_listing_id),
    status: String(listing.status),
  });
  return json({ listing: productListingView(listing) }, 201);
}

async function handleUpdateProductListing(
  req: Request,
  sql: DbClient,
  user: UserView,
  listingId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const write = parseProductListingWrite(body);
  if (!write || write.version === null) {
    return json({ error: 'invalid_product_listing' }, 400);
  }

  const listing = await sql.begin(async (tx) => {
    const currentRows = await tx`
      SELECT *
      FROM public.hdc_product_listings
      WHERE id = ${listingId} AND seller_user_id = ${user.id}
      FOR UPDATE
    `;
    if (currentRows.length === 0) {
      throw new WorkflowHttpError(
        'product_listing_not_found',
        404,
        'The product listing was not found.',
      );
    }
    const current = rowObject(currentRows[0]);
    const currentStatus = String(current.status);
    if (!isProductListingStatus(currentStatus)) {
      throw new Error('Invalid stored HDC product-listing status.');
    }
    if (Number(current.version) !== write.version) {
      throw new WorkflowHttpError(
        'product_listing_conflict',
        409,
        'The product listing changed elsewhere. Refresh and try again.',
      );
    }
    if (!canTransitionProductListing(currentStatus, write.status)) {
      throw new WorkflowHttpError(
        'invalid_product_listing_transition',
        409,
        'That product-listing status change is not allowed.',
      );
    }

    const profile = await activeSellingProfile(
      tx as unknown as DbClient,
      user.id,
      write.sellerRole,
    );
    if (!profile) {
      throw new WorkflowHttpError(
        'selling_role_required',
        403,
        'An approved Seller, Supplier, or Store profile is required.',
      );
    }

    const updatedRows = await tx`
      UPDATE public.hdc_product_listings
      SET
        seller_profile_id = ${String(profile.id)},
        seller_role = ${write.sellerRole},
        category_code = ${write.categoryCode},
        title = ${write.title},
        description = ${write.description},
        item_condition = ${write.condition},
        currency = ${write.currency},
        unit_price_minor = ${write.unitPriceMinor},
        stock_quantity = ${write.stockQuantity},
        status = ${write.status},
        published_at = CASE
          WHEN ${write.status} = 'active' THEN COALESCE(published_at, now())
          ELSE published_at
        END,
        sold_at = CASE
          WHEN ${write.status} = 'sold' THEN COALESCE(sold_at, now())
          WHEN ${write.status} = 'archived' THEN sold_at
          ELSE NULL
        END,
        archived_at = CASE
          WHEN ${write.status} = 'archived' THEN COALESCE(archived_at, now())
          ELSE NULL
        END
      WHERE id = ${listingId}
        AND seller_user_id = ${user.id}
      RETURNING *
    `;
    const updated = rowObject(updatedRows[0]);
    await tx`
      INSERT INTO public.hdc_product_listing_events (
        listing_id, actor_user_id, event_type, from_status, to_status, snapshot
      ) VALUES (
        ${listingId}, ${user.id},
        ${currentStatus === write.status ? 'updated' : 'status_changed'},
        ${currentStatus}, ${write.status},
        ${tx.json({
          sellerRole: write.sellerRole,
          categoryCode: write.categoryCode,
          stockQuantity: write.stockQuantity,
          version: Number(updated.version),
        })}
      )
    `;
    return updated;
  });

  await audit(sql, user.id, 'commerce.listing.update', 'success', {
    listing_id: listingId,
    status: String(listing.status),
    version: Number(listing.version),
  });
  return json({ listing: productListingView(listing) });
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

async function messagingTransaction(
  tx: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Record<string, unknown>> {
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
      'The service transaction was not found.',
    );
  }
  const transaction = rowObject(rows[0]);
  if (
    user.id !== String(transaction.customer_id) &&
    user.id !== String(transaction.technician_id)
  ) {
    throw new WorkflowHttpError(
      'forbidden',
      403,
      'Only transaction participants can access private chat.',
    );
  }
  return transaction;
}

async function ensurePrivateConversation(
  tx: DbClient,
  transaction: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const transactionId = String(transaction.id);
  const existing = await tx`
    SELECT *
    FROM public.hdc_private_conversations
    WHERE transaction_id = ${transactionId}
    LIMIT 1
  `;
  if (existing.length > 0) return rowObject(existing[0]);

  if (String(transaction.status) === 'cancelled') {
    throw new WorkflowHttpError(
      'private_messaging_unavailable',
      409,
      'Private messaging is not available for this transaction.',
    );
  }

  const conversationId = newWorkflowId('CONV');
  const created = await tx`
    INSERT INTO public.hdc_private_conversations (
      id, transaction_id, customer_id, technician_id, storage_mode,
      quota_bytes, external_provider_connected, storage_choice_confirmed
    ) VALUES (
      ${conversationId}, ${transactionId},
      ${String(transaction.customer_id)}, ${String(transaction.technician_id)},
      'hdcManaged', ${PRIVATE_CONVERSATION_BETA_QUOTA_BYTES}, false, false
    )
    RETURNING *
  `;
  return rowObject(created[0]);
}

async function privateConversationPayload(
  tx: DbClient,
  transactionId: string,
  changedSince: Date | null = null,
): Promise<Record<string, unknown>> {
  const conversations = await tx`
    SELECT *
    FROM public.hdc_private_conversations
    WHERE transaction_id = ${transactionId}
    LIMIT 1
  `;
  if (conversations.length === 0) {
    throw new WorkflowHttpError(
      'private_conversation_not_found',
      404,
      'The private conversation has not been started yet.',
    );
  }
  const conversation = rowObject(conversations[0]);
  const messages = changedSince === null
    ? await tx`
        SELECT *
        FROM public.hdc_private_messages
        WHERE conversation_id = ${String(conversation.id)}
        ORDER BY created_at, id
      `
    : await tx`
        SELECT *
        FROM public.hdc_private_messages
        WHERE conversation_id = ${String(conversation.id)}
          AND updated_at >= ${new Date(changedSince.getTime() - 5000)}
        ORDER BY created_at, id
      `;
  return privateConversationView(
    conversation,
    messages.map((row) => rowObject(row)),
  );
}

async function handlePrivateConversation(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'GET' && req.method !== 'POST') {
    return methodNotAllowed();
  }

  const sinceValue = new URL(req.url).searchParams.get('since');
  const changedSince = sinceValue === null ? null : new Date(sinceValue);
  if (changedSince !== null && Number.isNaN(changedSince.getTime())) {
    throw new WorkflowHttpError(
      'invalid_private_message_cursor',
      400,
      'The private-message synchronization cursor is invalid.',
    );
  }

  const conversation = await withWorkflowAuthority(sql, user, async (tx) => {
    const transaction = await messagingTransaction(tx, user, transactionId);
    if (req.method === 'POST') {
      await ensurePrivateConversation(tx, transaction);
    }
    return await privateConversationPayload(
      tx,
      transactionId,
      req.method === 'GET' ? changedSince : null,
    );
  });

  if (req.method === 'POST') {
    await audit(sql, user.id, 'messaging.conversation.ensure', 'success', {
      transaction_id: transactionId,
    });
  }
  return json({
    conversation,
    incremental: req.method === 'GET' && changedSince !== null,
  });
}

async function handleSendPrivateMessage(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parsePrivateMessageWrite(body);
  const moderation = assessPrivateMessage(input.text);
  if (moderation.action === 'block') {
    throw new WorkflowHttpError(
      'private_message_blocked',
      422,
      moderation.reason ?? 'HDC cannot send this message.',
    );
  }
  if (
    moderation.action === 'warn' &&
    !input.acknowledgeLanguageWarning
  ) {
    throw new WorkflowHttpError(
      'private_message_warning_required',
      409,
      moderation.reason ??
        'This message contains language that may be offensive.',
    );
  }

  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    const transaction = await messagingTransaction(tx, user, transactionId);
    if (String(transaction.status) === 'cancelled') {
      throw new WorkflowHttpError(
        'private_messaging_unavailable',
        409,
        'Private messaging is not available for this transaction.',
      );
    }
    const conversation = await ensurePrivateConversation(tx, transaction);
    if (
      String(conversation.storage_mode) === 'userOwned' &&
      conversation.external_provider_connected !== true
    ) {
      throw new WorkflowHttpError(
        'user_storage_not_connected',
        409,
        'User-owned chat storage is not connected yet.',
      );
    }

    const usageRows = await tx`
      SELECT COALESCE(sum(octet_length(body) + 160), 0)::bigint AS used_bytes
      FROM public.hdc_private_messages
      WHERE conversation_id = ${String(conversation.id)}
        AND status <> 'deleted'
    `;
    const usedBytes = Number(usageRows[0]?.used_bytes ?? 0);
    const projectedBytes = usedBytes + privateMessageStorageBytes(input.text);
    if (
      String(conversation.storage_mode) === 'hdcManaged' &&
      projectedBytes > Number(conversation.quota_bytes)
    ) {
      throw new WorkflowHttpError(
        'private_message_quota_exceeded',
        409,
        'HDC chat storage is full for this conversation.',
      );
    }

    const messageId = newWorkflowId('MSG');
    const insertedRows = await tx`
      INSERT INTO public.hdc_private_messages (
        id, conversation_id, sender_id, client_message_id, body, status,
        language_warning_acknowledged
      ) VALUES (
        ${messageId}, ${String(conversation.id)}, ${user.id},
        ${input.clientMessageId}, ${input.text}, 'sent',
        ${moderation.action === 'warn' &&
          input.acknowledgeLanguageWarning}
      )
      ON CONFLICT (conversation_id, sender_id, client_message_id)
      DO NOTHING
      RETURNING *
    `;
    let canonicalMessageId = messageId;
    let replayed = false;
    if (insertedRows.length === 0) {
      const replayRows = await tx`
        SELECT *
        FROM public.hdc_private_messages
        WHERE conversation_id = ${String(conversation.id)}
          AND sender_id = ${user.id}
          AND client_message_id = ${input.clientMessageId}
        LIMIT 1
      `;
      if (
        replayRows.length === 0 ||
        String(replayRows[0].body) !== input.text ||
        Boolean(replayRows[0].language_warning_acknowledged) !==
          (moderation.action === 'warn' && input.acknowledgeLanguageWarning)
      ) {
        throw new WorkflowHttpError(
          'private_message_identifier_conflict',
          409,
          'That private message reference is already in use.',
        );
      }
      canonicalMessageId = String(replayRows[0].id);
      replayed = true;
    }
    return {
      conversation: await privateConversationPayload(tx, transactionId),
      messageId: canonicalMessageId,
      replayed,
      transaction,
    };
  });

  await audit(sql, user.id, 'messaging.message.send', 'success', {
    transaction_id: transactionId,
    message_id: result.messageId,
    idempotent_replay: result.replayed,
  });
  if (!result.replayed) {
    await notifyTransactionCounterparty(
      sql,
      result.transaction,
      user.id,
      'messaging.message_received',
      'New private transaction message',
      'A participant sent a new message in your service workspace.',
      { transactionId, messageId: result.messageId },
    );
  }
  return json(
    {
      conversation: result.conversation,
      idempotentReplay: result.replayed,
    },
    result.replayed ? 200 : 201,
  );
}

async function handleMarkPrivateConversationRead(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();

  const conversation = await withWorkflowAuthority(sql, user, async (tx) => {
    const transaction = await messagingTransaction(tx, user, transactionId);
    const existing = await ensurePrivateConversation(tx, transaction);
    await tx`
      UPDATE public.hdc_private_messages
      SET status = 'read', read_at = COALESCE(read_at, now())
      WHERE conversation_id = ${String(existing.id)}
        AND sender_id <> ${user.id}
        AND status IN ('sent', 'delivered')
    `;
    return await privateConversationPayload(tx, transactionId);
  });

  return json({ conversation });
}

async function handlePrivateConversationStorage(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const mode = parseConversationStorageMode(body);

  const conversation = await withWorkflowAuthority(sql, user, async (tx) => {
    const transaction = await messagingTransaction(tx, user, transactionId);
    const existing = await ensurePrivateConversation(tx, transaction);
    await tx`
      UPDATE public.hdc_private_conversations
      SET storage_mode = ${mode}, storage_choice_confirmed = true
      WHERE id = ${String(existing.id)}
    `;
    return await privateConversationPayload(tx, transactionId);
  });

  await audit(sql, user.id, 'messaging.storage.update', 'success', {
    transaction_id: transactionId,
    storage_mode: mode,
  });
  return json({ conversation });
}

async function transactionForParticipant(
  tx: DbClient,
  user: UserView,
  transactionId: string,
  lock = false,
): Promise<Record<string, unknown>> {
  const rows = lock
    ? await tx`
        SELECT *
        FROM public.hdc_service_transactions
        WHERE id = ${transactionId}
        FOR UPDATE
      `
    : await tx`
        SELECT *
        FROM public.hdc_service_transactions
        WHERE id = ${transactionId}
      `;
  if (rows.length === 0) {
    throw new WorkflowHttpError(
      'service_transaction_not_found',
      404,
      'The service transaction was not found.',
    );
  }
  const transaction = rowObject(rows[0]);
  if (
    user.id !== String(transaction.customer_id) &&
    user.id !== String(transaction.technician_id)
  ) {
    throw new WorkflowHttpError(
      'forbidden',
      403,
      'Only transaction participants can use this service workspace.',
    );
  }
  return transaction;
}

function transactionActivity(
  transaction: Record<string, unknown>,
  actorId: string,
  type: string,
  message: string,
  toStatus: string | null = null,
): DbJsonValue[] {
  const currentActivity = Array.isArray(transaction.activity)
    ? transaction.activity as DbJsonValue[]
    : [];
  return [
    ...currentActivity,
    {
      id: newWorkflowId('TXN-ACT'),
      type,
      message,
      createdAt: new Date().toISOString(),
      fromStatus: String(transaction.status),
      toStatus: toStatus ?? String(transaction.status),
      actorId,
    },
  ];
}

async function authorizedTransactionTotalMinor(
  tx: DbClient,
  transaction: Record<string, unknown>,
): Promise<number> {
  const changeRows = await tx`
    SELECT total_minor
    FROM public.hdc_service_change_orders
    WHERE transaction_id = ${String(transaction.id)}
      AND status = 'accepted'
    ORDER BY decided_at DESC, created_at DESC
    LIMIT 1
  `;
  if (changeRows.length > 0) return Number(changeRows[0].total_minor);
  const acceptedTerms = transaction.accepted_terms &&
      typeof transaction.accepted_terms === 'object' &&
      !Array.isArray(transaction.accepted_terms)
    ? transaction.accepted_terms as Record<string, unknown>
    : {};
  return Math.max(
    0,
    Math.round(Number(acceptedTerms.totalEstimate ?? 0) * 100),
  );
}

async function transactionToolboxPayload(
  tx: DbClient,
  transaction: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const transactionId = String(transaction.id);
  const schedules = await tx`
    SELECT * FROM public.hdc_service_schedule_changes
    WHERE transaction_id = ${transactionId}
    ORDER BY created_at DESC
  `;
  const changeOrders = await tx`
    SELECT * FROM public.hdc_service_change_orders
    WHERE transaction_id = ${transactionId}
    ORDER BY created_at DESC
  `;
  const exceptions = await tx`
    SELECT * FROM public.hdc_service_transaction_exceptions
    WHERE transaction_id = ${transactionId}
    ORDER BY created_at DESC
  `;
  const payments = await tx`
    SELECT * FROM public.hdc_service_payments
    WHERE transaction_id = ${transactionId}
    ORDER BY created_at DESC
  `;
  const paymentEvents = await tx`
    SELECT * FROM public.hdc_service_payment_events
    WHERE transaction_id = ${transactionId}
    ORDER BY created_at, id
  `;
  const receipts = await tx`
    SELECT * FROM public.hdc_service_receipts
    WHERE transaction_id = ${transactionId}
    ORDER BY issued_at DESC
  `;
  const documents = await tx`
    SELECT * FROM public.hdc_service_documents
    WHERE transaction_id = ${transactionId}
      AND visibility = 'participants'
      AND status <> 'removed'
    ORDER BY created_at DESC
  `;
  const disputes = await tx`
    SELECT * FROM public.hdc_service_disputes
    WHERE transaction_id = ${transactionId}
    ORDER BY created_at DESC
  `;
  const disputeEvents = await tx`
    SELECT * FROM public.hdc_service_dispute_events
    WHERE transaction_id = ${transactionId}
    ORDER BY created_at, id
  `;
  const authorizedTotalMinor = await authorizedTransactionTotalMinor(
    tx,
    transaction,
  );
  const confirmedPaidMinor = payments.reduce((total, row) => {
    const status = String(row.status);
    if (!['confirmed', 'partiallyRefunded', 'refunded'].includes(status)) {
      return total;
    }
    return total + Number(row.amount_minor) - Number(row.refunded_minor ?? 0);
  }, 0);
  return {
    transactionId,
    authorizedTotalMinor,
    confirmedPaidMinor,
    balanceMinor: Math.max(0, authorizedTotalMinor - confirmedPaidMinor),
    currency: 'PHP',
    schedules: schedules.map((row) => scheduleChangeView(rowObject(row))),
    changeOrders: changeOrders.map((row) => changeOrderView(rowObject(row))),
    exceptions: exceptions.map((row) =>
      transactionExceptionView(rowObject(row))),
    payments: payments.map((row) => paymentView(rowObject(row))),
    paymentEvents: paymentEvents.map((row) =>
      paymentEventView(rowObject(row))),
    receipts: receipts.map((row) => receiptView(rowObject(row))),
    documents: documents.map((row) => documentView(rowObject(row))),
    disputes: disputes.map((row) => disputeView(rowObject(row))),
    disputeEvents: disputeEvents.map((row) =>
      disputeEventView(rowObject(row))),
    updatedAt: new Date().toISOString(),
  };
}

async function handleTransactionToolbox(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  const toolbox = await withWorkflowAuthority(sql, user, async (tx) => {
    const transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
    );
    return await transactionToolboxPayload(tx, transaction);
  });
  return json({ toolbox });
}

async function handleCreateScheduleChange(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseScheduleChangeWrite(body);
  if (new Date(input.proposedFor).getTime() <= Date.now()) {
    throw new WorkflowHttpError(
      'schedule_must_be_future',
      409,
      'Choose a future service date and time.',
    );
  }

  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    const transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
      true,
    );
    if (['completed', 'cancelled', 'disputed'].includes(String(transaction.status))) {
      throw new WorkflowHttpError(
        'schedule_change_unavailable',
        409,
        'This transaction cannot be rescheduled in its current state.',
      );
    }
    const replayRows = await tx`
      SELECT * FROM public.hdc_service_schedule_changes
      WHERE transaction_id = ${transactionId}
        AND proposed_by = ${user.id}
        AND client_reference = ${input.clientReference}
      LIMIT 1
    `;
    if (replayRows.length > 0) {
      const replay = rowObject(replayRows[0]);
      if (
        new Date(String(replay.proposed_for)).getTime() !==
          new Date(input.proposedFor).getTime() ||
        String(replay.note ?? '') !== input.note
      ) {
        throw new WorkflowHttpError(
          'schedule_reference_conflict',
          409,
          'That schedule-change reference is already in use.',
        );
      }
      return {
        transaction,
        toolbox: await transactionToolboxPayload(tx, transaction),
        replayed: true,
      };
    }
    const pendingRows = await tx`
      SELECT id FROM public.hdc_service_schedule_changes
      WHERE transaction_id = ${transactionId}
        AND status = 'pending'
      LIMIT 1
    `;
    if (pendingRows.length > 0) {
      throw new WorkflowHttpError(
        'schedule_change_pending',
        409,
        'Decide or withdraw the current schedule proposal first.',
      );
    }
    await tx`
      INSERT INTO public.hdc_service_schedule_changes (
        id, transaction_id, client_reference, proposed_by,
        proposed_for, note, status
      ) VALUES (
        ${newWorkflowId('SCH')}, ${transactionId}, ${input.clientReference},
        ${user.id}, ${input.proposedFor}, ${input.note}, 'pending'
      )
    `;
    return {
      transaction,
      toolbox: await transactionToolboxPayload(tx, transaction),
      replayed: false,
    };
  });

  if (!result.replayed) {
    await audit(sql, user.id, 'workflow.schedule.proposed', 'success', {
      transaction_id: transactionId,
    });
    await notifyTransactionCounterparty(
      sql,
      result.transaction,
      user.id,
      'workflow.schedule_proposed',
      'Schedule change requested',
      'A new service date and time is waiting for your decision.',
      { transactionId },
      'high',
    );
  }
  return json(
    { toolbox: result.toolbox, idempotentReplay: result.replayed },
    result.replayed ? 200 : 201,
  );
}

async function handleScheduleChangeDecision(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
  scheduleId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseParticipantDecisionWrite(body);
  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    let transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
      true,
    );
    const rows = await tx`
      SELECT * FROM public.hdc_service_schedule_changes
      WHERE id = ${scheduleId}
        AND transaction_id = ${transactionId}
      FOR UPDATE
    `;
    if (rows.length === 0) {
      throw new WorkflowHttpError(
        'schedule_change_not_found',
        404,
        'That schedule change was not found.',
      );
    }
    const schedule = rowObject(rows[0]);
    if (String(schedule.status) !== 'pending') {
      throw new WorkflowHttpError(
        'schedule_change_decided',
        409,
        'That schedule change has already been decided.',
      );
    }
    const proposerId = String(schedule.proposed_by);
    const withdrawing = input.action === 'withdraw';
    if (String(transaction.status) === 'disputed' && !withdrawing) {
      throw new WorkflowHttpError(
        'transaction_frozen_by_dispute',
        409,
        'Schedule decisions are frozen while the dispute is active.',
      );
    }
    if (withdrawing ? proposerId !== user.id : proposerId === user.id) {
      throw new WorkflowHttpError(
        'schedule_decision_forbidden',
        403,
        withdrawing
          ? 'Only the proposer can withdraw this schedule change.'
          : 'The other participant must decide this schedule change.',
      );
    }
    const status = input.action === 'accept'
      ? 'accepted'
      : input.action === 'decline'
        ? 'declined'
        : 'withdrawn';
    await tx`
      UPDATE public.hdc_service_schedule_changes
      SET
        status = ${status},
        decided_by = ${withdrawing ? null : user.id},
        decided_at = now(),
        note = CASE
          WHEN ${input.note} = '' THEN note
          ELSE ${input.note}
        END
      WHERE id = ${scheduleId}
    `;
    if (status === 'accepted') {
      const nextStatus = String(transaction.status) === 'confirmed'
        ? 'scheduled'
        : String(transaction.status);
      const activity = transactionActivity(
        transaction,
        user.id,
        'statusChanged',
        `Service schedule changed to ${new Date(
          String(schedule.proposed_for),
        ).toISOString()}.`,
        nextStatus,
      );
      const transactionRows = await tx`
        UPDATE public.hdc_service_transactions
        SET status = ${nextStatus}, activity = ${tx.json(activity)}
        WHERE id = ${transactionId}
        RETURNING *
      `;
      transaction = rowObject(transactionRows[0]);
    }
    return {
      transaction,
      status,
      toolbox: await transactionToolboxPayload(tx, transaction),
    };
  });

  await audit(sql, user.id, 'workflow.schedule.decision', 'success', {
    transaction_id: transactionId,
    schedule_id: scheduleId,
    status: result.status,
  });
  await notifyTransactionCounterparty(
    sql,
    result.transaction,
    user.id,
    'workflow.schedule_decided',
    'Schedule request updated',
    `The schedule request was ${result.status}.`,
    { transactionId, scheduleId, status: result.status },
  );
  return json({ toolbox: result.toolbox });
}

async function handleCreateChangeOrder(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseChangeOrderWrite(body);
  if (input.serviceFeeMinor + input.partsCostMinor <= 0) {
    throw new WorkflowHttpError(
      'invalid_change_order_amount',
      400,
      'The revised total must be greater than zero.',
    );
  }
  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    const transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
      true,
    );
    if (String(transaction.technician_id) !== user.id) {
      throw new WorkflowHttpError(
        'change_order_forbidden',
        403,
        'Only the assigned technician can propose a revised price.',
      );
    }
    if (['completed', 'cancelled', 'disputed'].includes(String(transaction.status))) {
      throw new WorkflowHttpError(
        'change_order_unavailable',
        409,
        'A price change is not available in the current transaction state.',
      );
    }
    const replayRows = await tx`
      SELECT * FROM public.hdc_service_change_orders
      WHERE transaction_id = ${transactionId}
        AND proposed_by = ${user.id}
        AND client_reference = ${input.clientReference}
      LIMIT 1
    `;
    if (replayRows.length > 0) {
      const replay = rowObject(replayRows[0]);
      if (
        String(replay.reason) !== input.reason ||
        Number(replay.service_fee_minor) !== input.serviceFeeMinor ||
        Number(replay.parts_cost_minor) !== input.partsCostMinor ||
        String(replay.currency) !== input.currency
      ) {
        throw new WorkflowHttpError(
          'change_order_reference_conflict',
          409,
          'That price-change reference is already in use.',
        );
      }
      return {
        transaction,
        toolbox: await transactionToolboxPayload(tx, transaction),
        replayed: true,
      };
    }
    const pendingRows = await tx`
      SELECT id FROM public.hdc_service_change_orders
      WHERE transaction_id = ${transactionId}
        AND status = 'pending'
      LIMIT 1
    `;
    if (pendingRows.length > 0) {
      throw new WorkflowHttpError(
        'change_order_pending',
        409,
        'The customer must decide the current price change first.',
      );
    }
    await tx`
      INSERT INTO public.hdc_service_change_orders (
        id, transaction_id, client_reference, proposed_by, reason,
        service_fee_minor, parts_cost_minor, total_minor, currency, status
      ) VALUES (
        ${newWorkflowId('CHG')}, ${transactionId}, ${input.clientReference},
        ${user.id}, ${input.reason}, ${input.serviceFeeMinor},
        ${input.partsCostMinor},
        ${input.serviceFeeMinor + input.partsCostMinor}, ${input.currency},
        'pending'
      )
    `;
    return {
      transaction,
      toolbox: await transactionToolboxPayload(tx, transaction),
      replayed: false,
    };
  });

  if (!result.replayed) {
    await audit(sql, user.id, 'workflow.change_order.proposed', 'success', {
      transaction_id: transactionId,
    });
    await notifyTransactionCounterparty(
      sql,
      result.transaction,
      user.id,
      'workflow.change_order_proposed',
      'Price change awaiting approval',
      'The technician proposed a revised service total. Review it before payment.',
      { transactionId },
      'high',
    );
  }
  return json(
    { toolbox: result.toolbox, idempotentReplay: result.replayed },
    result.replayed ? 200 : 201,
  );
}

async function handleChangeOrderDecision(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
  changeOrderId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseParticipantDecisionWrite(body);
  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    let transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
      true,
    );
    const rows = await tx`
      SELECT * FROM public.hdc_service_change_orders
      WHERE id = ${changeOrderId}
        AND transaction_id = ${transactionId}
      FOR UPDATE
    `;
    if (rows.length === 0) {
      throw new WorkflowHttpError(
        'change_order_not_found',
        404,
        'That price change was not found.',
      );
    }
    const change = rowObject(rows[0]);
    if (String(change.status) !== 'pending') {
      throw new WorkflowHttpError(
        'change_order_decided',
        409,
        'That price change has already been decided.',
      );
    }
    const proposerId = String(change.proposed_by);
    const withdrawing = input.action === 'withdraw';
    if (String(transaction.status) === 'disputed' && !withdrawing) {
      throw new WorkflowHttpError(
        'transaction_frozen_by_dispute',
        409,
        'Price decisions are frozen while the dispute is active.',
      );
    }
    if (withdrawing ? proposerId !== user.id : proposerId === user.id) {
      throw new WorkflowHttpError(
        'change_order_decision_forbidden',
        403,
        withdrawing
          ? 'Only the technician can withdraw this price change.'
          : 'Only the customer can decide this price change.',
      );
    }
    const status = input.action === 'accept'
      ? 'accepted'
      : input.action === 'decline'
        ? 'declined'
        : 'withdrawn';
    await tx`
      UPDATE public.hdc_service_change_orders
      SET
        status = ${status},
        decided_by = ${withdrawing ? null : user.id},
        decided_at = now()
      WHERE id = ${changeOrderId}
    `;
    if (status === 'accepted') {
      const currentTerms = transaction.accepted_terms &&
          typeof transaction.accepted_terms === 'object' &&
          !Array.isArray(transaction.accepted_terms)
        ? transaction.accepted_terms as Record<
          string,
          DbJsonValue | undefined
        >
        : {};
      const revisedTerms = {
        ...currentTerms,
        originalTotalEstimate:
          currentTerms.originalTotalEstimate ?? currentTerms.totalEstimate,
        serviceFee: Number(change.service_fee_minor) / 100,
        estimatedPartsCost: Number(change.parts_cost_minor) / 100,
        totalEstimate: Number(change.total_minor) / 100,
        latestAcceptedChangeOrderId: changeOrderId,
      };
      const activity = transactionActivity(
        transaction,
        user.id,
        'statusChanged',
        'Customer approved a revised service price.',
      );
      const transactionRows = await tx`
        UPDATE public.hdc_service_transactions
        SET accepted_terms = ${tx.json(revisedTerms)}, activity = ${tx.json(activity)}
        WHERE id = ${transactionId}
        RETURNING *
      `;
      transaction = rowObject(transactionRows[0]);
    }
    return {
      transaction,
      status,
      toolbox: await transactionToolboxPayload(tx, transaction),
    };
  });

  await audit(sql, user.id, 'workflow.change_order.decision', 'success', {
    transaction_id: transactionId,
    change_order_id: changeOrderId,
    status: result.status,
  });
  await notifyTransactionCounterparty(
    sql,
    result.transaction,
    user.id,
    'workflow.change_order_decided',
    'Price change updated',
    `The revised service price was ${result.status}.`,
    { transactionId, changeOrderId, status: result.status },
  );
  return json({ toolbox: result.toolbox });
}

async function handleCreateTransactionException(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseTransactionExceptionWrite(body);
  if (
    ['customerNoShow', 'technicianNoShow', 'customerNonResponse'].includes(
      input.exceptionType,
    ) && input.reason.length < 20
  ) {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      'Describe the no-show or non-response in at least 20 characters.',
    );
  }
  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    let transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
      true,
    );
    const customerId = String(transaction.customer_id);
    const technicianId = String(transaction.technician_id);
    if (String(transaction.status) === 'disputed') {
      throw new WorkflowHttpError(
        'transaction_frozen_by_dispute',
        409,
        'Service exception changes are frozen while the dispute is active.',
      );
    }
    if (
      (input.exceptionType === 'customerNoShow' ||
        input.exceptionType === 'customerNonResponse') &&
      user.id !== technicianId
    ) {
      throw new WorkflowHttpError(
        'exception_report_forbidden',
        403,
        'Only the assigned technician can report this customer issue.',
      );
    }
    if (
      input.exceptionType === 'technicianNoShow' &&
      user.id !== customerId
    ) {
      throw new WorkflowHttpError(
        'exception_report_forbidden',
        403,
        'Only the customer can report a technician no-show.',
      );
    }
    const replayRows = await tx`
      SELECT * FROM public.hdc_service_transaction_exceptions
      WHERE transaction_id = ${transactionId}
        AND reported_by = ${user.id}
        AND client_reference = ${input.clientReference}
      LIMIT 1
    `;
    if (replayRows.length > 0) {
      const replay = rowObject(replayRows[0]);
      if (
        String(replay.exception_type) !== input.exceptionType ||
        String(replay.reason) !== input.reason
      ) {
        throw new WorkflowHttpError(
          'exception_reference_conflict',
          409,
          'That service-issue reference is already in use.',
        );
      }
      return {
        transaction,
        toolbox: await transactionToolboxPayload(tx, transaction),
        replayed: true,
      };
    }

    if (input.exceptionType === 'cancellation') {
      if (
        ['inProgress', 'awaitingCustomerConfirmation', 'completed',
          'cancelled', 'disputed'].includes(String(transaction.status))
      ) {
        throw new WorkflowHttpError(
          'transaction_cancellation_unavailable',
          409,
          'This transaction now requires the dispute workflow instead of direct cancellation.',
        );
      }
    } else if (['completed', 'cancelled'].includes(String(transaction.status))) {
      throw new WorkflowHttpError(
        'transaction_exception_unavailable',
        409,
        'This service issue cannot be recorded in the current state.',
      );
    }

    const exceptionId = newWorkflowId('TXN-EXC');
    await tx`
      INSERT INTO public.hdc_service_transaction_exceptions (
        id, transaction_id, client_reference, reported_by,
        exception_type, reason, status
      ) VALUES (
        ${exceptionId}, ${transactionId}, ${input.clientReference},
        ${user.id}, ${input.exceptionType}, ${input.reason},
        ${['customerNoShow', 'technicianNoShow', 'customerNonResponse'].includes(
          input.exceptionType,
        ) ? 'underReview' : 'recorded'}
      )
    `;

    if (input.exceptionType === 'cancellation') {
      const activity = transactionActivity(
        transaction,
        user.id,
        'cancelled',
        `Service cancelled: ${input.reason}`,
        'cancelled',
      );
      const transactionRows = await tx`
        UPDATE public.hdc_service_transactions
        SET status = 'cancelled', activity = ${tx.json(activity)}
        WHERE id = ${transactionId}
        RETURNING *
      `;
      await tx`
        UPDATE public.hdc_service_requests
        SET status = 'cancelled'
        WHERE id = ${String(transaction.request_id)}
      `;
      transaction = rowObject(transactionRows[0]);
    } else if (
      ['customerNoShow', 'technicianNoShow', 'customerNonResponse'].includes(
        input.exceptionType,
      )
    ) {
      const priorStatus = String(transaction.status);
      const activeRows = await tx`
        SELECT id FROM public.hdc_service_disputes
        WHERE transaction_id = ${transactionId}
          AND status IN ('open', 'underReview')
        LIMIT 1
      `;
      if (activeRows.length === 0) {
        const disputeId = newWorkflowId('DSP');
        await tx`
          INSERT INTO public.hdc_service_disputes (
            id, transaction_id, client_reference, opened_by, reason_code,
            summary, requested_outcome, prior_transaction_status, status
          ) VALUES (
            ${disputeId}, ${transactionId}, ${input.clientReference}, ${user.id},
            ${input.exceptionType.includes('NoShow') ? 'noShow' : 'completion'},
            ${input.reason}, 'cancelService', ${priorStatus}, 'open'
          )
        `;
        await tx`
          INSERT INTO public.hdc_service_dispute_events (
            id, dispute_id, transaction_id, actor_id, event_type, message
          ) VALUES (
            ${newWorkflowId('DSP-EVT')}, ${disputeId}, ${transactionId},
            ${user.id}, 'opened', ${input.reason}
          )
        `;
      }
      const activity = transactionActivity(
        transaction,
        user.id,
        'disputeOpened',
        'A no-show or non-response report opened a dispute review.',
        'disputed',
      );
      const transactionRows = await tx`
        UPDATE public.hdc_service_transactions
        SET status = 'disputed', activity = ${tx.json(activity)}
        WHERE id = ${transactionId}
        RETURNING *
      `;
      transaction = rowObject(transactionRows[0]);
    }

    return {
      transaction,
      toolbox: await transactionToolboxPayload(tx, transaction),
      replayed: false,
    };
  });

  if (!result.replayed) {
    await audit(sql, user.id, 'workflow.transaction.exception', 'success', {
      transaction_id: transactionId,
      exception_type: input.exceptionType,
    });
    await notifyTransactionCounterparty(
      sql,
      result.transaction,
      user.id,
      'workflow.transaction_exception',
      input.exceptionType === 'cancellation'
        ? 'Service cancelled'
        : 'Service issue reported',
      input.exceptionType === 'cancellation'
        ? 'The other participant cancelled this service transaction.'
        : 'A no-show, non-response, or service issue was recorded.',
      { transactionId, exceptionType: input.exceptionType },
      'critical',
    );
  }
  return json(
    { toolbox: result.toolbox, idempotentReplay: result.replayed },
    result.replayed ? 200 : 201,
  );
}

async function handleCreateServicePayment(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parsePaymentWrite(body);
  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    const transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
      true,
    );
    if (String(transaction.customer_id) !== user.id) {
      throw new WorkflowHttpError(
        'payment_record_forbidden',
        403,
        'Only the customer can record a payment for technician confirmation.',
      );
    }
    if (['cancelled', 'disputed'].includes(String(transaction.status))) {
      throw new WorkflowHttpError(
        'payment_unavailable',
        409,
        'Payment recording is frozen for this transaction.',
      );
    }
    const pendingChangeRows = await tx`
      SELECT id FROM public.hdc_service_change_orders
      WHERE transaction_id = ${transactionId}
        AND status = 'pending'
      LIMIT 1
    `;
    if (pendingChangeRows.length > 0) {
      throw new WorkflowHttpError(
        'change_order_pending',
        409,
        'Decide the pending price change before recording payment.',
      );
    }
    const replayRows = await tx`
      SELECT * FROM public.hdc_service_payments
      WHERE transaction_id = ${transactionId}
        AND recorded_by = ${user.id}
        AND client_reference = ${input.clientReference}
      LIMIT 1
    `;
    if (replayRows.length > 0) {
      const replay = rowObject(replayRows[0]);
      if (
        Number(replay.amount_minor) !== input.amountMinor ||
        String(replay.currency) !== input.currency ||
        String(replay.payment_method) !== input.paymentMethod ||
        String(replay.note ?? '') !== input.note ||
        (replay.external_reference ? String(replay.external_reference) : null) !==
          input.externalReference
      ) {
        throw new WorkflowHttpError(
          'payment_reference_conflict',
          409,
          'That payment reference is already in use.',
        );
      }
      return {
        transaction,
        toolbox: await transactionToolboxPayload(tx, transaction),
        replayed: true,
      };
    }
    const authorizedTotalMinor = await authorizedTransactionTotalMinor(
      tx,
      transaction,
    );
    const totals = await tx`
      SELECT COALESCE(sum(amount_minor - refunded_minor), 0)::bigint AS total
      FROM public.hdc_service_payments
      WHERE transaction_id = ${transactionId}
        AND status IN ('recorded', 'confirmed', 'partiallyRefunded', 'refunded')
    `;
    const existingTotal = Number(totals[0]?.total ?? 0);
    if (existingTotal + input.amountMinor > authorizedTotalMinor) {
      throw new WorkflowHttpError(
        'payment_exceeds_balance',
        409,
        'The recorded payment exceeds the currently approved balance.',
      );
    }
    const paymentId = newWorkflowId('PAY');
    await tx`
      INSERT INTO public.hdc_service_payments (
        id, transaction_id, client_reference, recorded_by, amount_minor,
        currency, payment_method, status, note, external_reference
      ) VALUES (
        ${paymentId}, ${transactionId}, ${input.clientReference}, ${user.id},
        ${input.amountMinor}, ${input.currency}, ${input.paymentMethod},
        'recorded', ${input.note}, ${input.externalReference}
      )
    `;
    await tx`
      INSERT INTO public.hdc_service_payment_events (
        id, payment_id, transaction_id, actor_id, event_type,
        amount_minor, note
      ) VALUES (
        ${newWorkflowId('PAY-EVT')}, ${paymentId}, ${transactionId},
        ${user.id}, 'recorded', ${input.amountMinor}, ${input.note}
      )
    `;
    return {
      transaction,
      toolbox: await transactionToolboxPayload(tx, transaction),
      replayed: false,
    };
  });

  if (!result.replayed) {
    await audit(sql, user.id, 'workflow.payment.recorded', 'success', {
      transaction_id: transactionId,
      amount_minor: input.amountMinor,
    });
    await notifyTransactionCounterparty(
      sql,
      result.transaction,
      user.id,
      'workflow.payment_recorded',
      'Payment awaiting confirmation',
      'The customer recorded a payment. Confirm only after receiving it.',
      { transactionId, amountMinor: input.amountMinor },
      'high',
    );
  }
  return json(
    { toolbox: result.toolbox, idempotentReplay: result.replayed },
    result.replayed ? 200 : 201,
  );
}

async function handleServicePaymentAction(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
  paymentId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parsePaymentActionWrite(body);
  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    const transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
      true,
    );
    const rows = await tx`
      SELECT * FROM public.hdc_service_payments
      WHERE id = ${paymentId}
        AND transaction_id = ${transactionId}
      FOR UPDATE
    `;
    if (rows.length === 0) {
      throw new WorkflowHttpError(
        'payment_not_found',
        404,
        'That payment record was not found.',
      );
    }
    const payment = rowObject(rows[0]);
    const customerId = String(transaction.customer_id);
    const technicianId = String(transaction.technician_id);
    const currentStatus = String(payment.status);
    if (String(transaction.status) === 'disputed') {
      throw new WorkflowHttpError(
        'transaction_frozen_by_dispute',
        409,
        'Payment and refund changes are frozen while the dispute is active.',
      );
    }
    let eventType: string = input.action;
    let eventAmount = input.amountMinor;
    let receiptType: 'payment' | 'refund' | null = null;
    let receiptAmount = 0;

    if (input.action === 'confirm' || input.action === 'reject') {
      if (user.id !== technicianId) {
        throw new WorkflowHttpError(
          'payment_confirmation_forbidden',
          403,
          'Only the assigned technician can confirm or reject a payment.',
        );
      }
      if (currentStatus !== 'recorded') {
        if (input.action === 'confirm' && currentStatus === 'confirmed') {
          return {
            transaction,
            toolbox: await transactionToolboxPayload(tx, transaction),
            replayed: true,
            eventType: 'confirmed',
          };
        }
        throw new WorkflowHttpError(
          'payment_already_decided',
          409,
          'That payment has already been decided.',
        );
      }
      const nextStatus = input.action === 'confirm' ? 'confirmed' : 'rejected';
      await tx`
        UPDATE public.hdc_service_payments
        SET status = ${nextStatus}, confirmed_by = ${user.id}, confirmed_at = now()
        WHERE id = ${paymentId}
      `;
      eventType = nextStatus;
      eventAmount = Number(payment.amount_minor);
      if (nextStatus === 'confirmed') {
        receiptType = 'payment';
        receiptAmount = Number(payment.amount_minor);
      }
    } else if (input.action === 'cancel') {
      if (user.id !== customerId || String(payment.recorded_by) !== user.id) {
        throw new WorkflowHttpError(
          'payment_cancel_forbidden',
          403,
          'Only the customer who recorded this pending payment can cancel it.',
        );
      }
      if (currentStatus !== 'recorded') {
        throw new WorkflowHttpError(
          'payment_already_decided',
          409,
          'Only a pending payment record can be cancelled.',
        );
      }
      await tx`
        UPDATE public.hdc_service_payments
        SET status = 'cancelled'
        WHERE id = ${paymentId}
      `;
      eventType = 'cancelled';
      eventAmount = Number(payment.amount_minor);
    } else if (input.action === 'recordRefund') {
      if (user.id !== technicianId) {
        throw new WorkflowHttpError(
          'refund_record_forbidden',
          403,
          'Only the technician can record a refund for customer confirmation.',
        );
      }
      if (!['confirmed', 'partiallyRefunded'].includes(currentStatus)) {
        throw new WorkflowHttpError(
          'refund_unavailable',
          409,
          'This payment is not available for a refund.',
        );
      }
      const pendingRows = await tx`
        SELECT event.id
        FROM public.hdc_service_payment_events event
        WHERE event.payment_id = ${paymentId}
          AND event.event_type = 'refundRecorded'
          AND NOT EXISTS (
            SELECT 1 FROM public.hdc_service_payment_events confirmation
            WHERE confirmation.related_event_id = event.id
              AND confirmation.event_type = 'refundConfirmed'
          )
        LIMIT 1
      `;
      if (pendingRows.length > 0) {
        throw new WorkflowHttpError(
          'refund_pending',
          409,
          'The customer must confirm the current refund first.',
        );
      }
      const remaining = Number(payment.amount_minor) -
        Number(payment.refunded_minor ?? 0);
      if ((input.amountMinor ?? 0) > remaining) {
        throw new WorkflowHttpError(
          'refund_exceeds_payment',
          409,
          'The refund amount exceeds the remaining confirmed payment.',
        );
      }
      const refundEventId = newWorkflowId('PAY-EVT');
      await tx`
        INSERT INTO public.hdc_service_payment_events (
          id, payment_id, transaction_id, actor_id, event_type,
          amount_minor, note
        ) VALUES (
          ${refundEventId}, ${paymentId}, ${transactionId}, ${user.id},
          'refundRecorded', ${input.amountMinor}, ${input.note}
        )
      `;
      return {
        transaction,
        toolbox: await transactionToolboxPayload(tx, transaction),
        replayed: false,
        eventType: 'refundRecorded',
      };
    } else {
      if (user.id !== customerId) {
        throw new WorkflowHttpError(
          'refund_confirmation_forbidden',
          403,
          'Only the customer can confirm receipt of a refund.',
        );
      }
      const refundRows = await tx`
        SELECT event.*
        FROM public.hdc_service_payment_events event
        WHERE event.payment_id = ${paymentId}
          AND event.event_type = 'refundRecorded'
          AND NOT EXISTS (
            SELECT 1 FROM public.hdc_service_payment_events confirmation
            WHERE confirmation.related_event_id = event.id
              AND confirmation.event_type = 'refundConfirmed'
          )
        ORDER BY event.created_at DESC
        LIMIT 1
        FOR UPDATE
      `;
      if (refundRows.length === 0) {
        throw new WorkflowHttpError(
          'refund_not_pending',
          409,
          'There is no refund awaiting confirmation.',
        );
      }
      const refund = rowObject(refundRows[0]);
      const amount = Number(refund.amount_minor);
      if (input.amountMinor !== amount) {
        throw new WorkflowHttpError(
          'refund_amount_mismatch',
          409,
          'The refund amount does not match the pending record.',
        );
      }
      const refundedMinor = Number(payment.refunded_minor ?? 0) + amount;
      const nextStatus = refundedMinor === Number(payment.amount_minor)
        ? 'refunded'
        : 'partiallyRefunded';
      await tx`
        UPDATE public.hdc_service_payments
        SET status = ${nextStatus}, refunded_minor = ${refundedMinor}
        WHERE id = ${paymentId}
      `;
      await tx`
        INSERT INTO public.hdc_service_payment_events (
          id, payment_id, transaction_id, actor_id, related_event_id,
          event_type, amount_minor, note
        ) VALUES (
          ${newWorkflowId('PAY-EVT')}, ${paymentId}, ${transactionId},
          ${user.id}, ${String(refund.id)}, 'refundConfirmed', ${amount},
          ${input.note}
        )
      `;
      receiptType = 'refund';
      receiptAmount = amount;
      eventType = 'refundConfirmed';
      eventAmount = amount;
    }

    if (!['recordRefund', 'confirmRefund'].includes(input.action)) {
      await tx`
        INSERT INTO public.hdc_service_payment_events (
          id, payment_id, transaction_id, actor_id, event_type,
          amount_minor, note
        ) VALUES (
          ${newWorkflowId('PAY-EVT')}, ${paymentId}, ${transactionId},
          ${user.id}, ${eventType}, ${eventAmount}, ${input.note}
        )
      `;
    }
    if (receiptType !== null) {
      const receiptId = newWorkflowId('HDC-RCPT');
      await tx`
        INSERT INTO public.hdc_service_receipts (
          id, payment_id, transaction_id, receipt_type, amount_minor,
          currency, issued_to, issued_by, verification_level, snapshot
        ) VALUES (
          ${receiptId}, ${paymentId}, ${transactionId}, ${receiptType},
          ${receiptAmount}, ${String(payment.currency)}, ${customerId},
          ${user.id}, 'participantConfirmed', ${tx.json({
            receiptId,
            transactionId,
            paymentId,
            receiptType,
            amountMinor: receiptAmount,
            currency: String(payment.currency),
            paymentMethod: String(payment.payment_method),
            providerVerified: false,
            verificationLabel: 'Confirmed by HDC transaction participants',
          })}
        )
      `;
    }
    return {
      transaction,
      toolbox: await transactionToolboxPayload(tx, transaction),
      replayed: false,
      eventType,
    };
  });

  if (!result.replayed) {
    await audit(sql, user.id, 'workflow.payment.action', 'success', {
      transaction_id: transactionId,
      payment_id: paymentId,
      action: result.eventType,
    });
    await notifyTransactionCounterparty(
      sql,
      result.transaction,
      user.id,
      'workflow.payment_updated',
      'Payment record updated',
      `A payment or refund record was updated: ${result.eventType}.`,
      { transactionId, paymentId, action: result.eventType },
      'high',
    );
  }
  return json({
    toolbox: result.toolbox,
    idempotentReplay: result.replayed,
  });
}

async function handleCreateTransactionDocument(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseDocumentWrite(body);
  const byteSize = utf8Bytes(input.content);
  if (byteSize > 100_000) {
    throw new WorkflowHttpError(
      'document_too_large',
      413,
      'This structured document is too large.',
    );
  }

  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    const transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
      true,
    );
    const replayRows = await tx`
      SELECT * FROM public.hdc_service_documents
      WHERE transaction_id = ${transactionId}
        AND created_by = ${user.id}
        AND client_reference = ${input.clientReference}
      LIMIT 1
    `;
    if (replayRows.length > 0) {
      const replay = rowObject(replayRows[0]);
      if (
        String(replay.document_type) !== input.documentType ||
        String(replay.title) !== input.title ||
        String(replay.content_text) !== input.content ||
        (replay.dispute_id ? String(replay.dispute_id) : null) !==
          input.disputeId
      ) {
        throw new WorkflowHttpError(
          'document_reference_conflict',
          409,
          'That document reference is already in use.',
        );
      }
      return {
        transaction,
        toolbox: await transactionToolboxPayload(tx, transaction),
        replayed: true,
      };
    }

    if (input.disputeId !== null) {
      const disputeRows = await tx`
        SELECT id FROM public.hdc_service_disputes
        WHERE id = ${input.disputeId}
          AND transaction_id = ${transactionId}
        LIMIT 1
      `;
      if (disputeRows.length === 0) {
        throw new WorkflowHttpError(
          'document_dispute_not_found',
          404,
          'The linked dispute was not found for this transaction.',
        );
      }
    }

    await tx`
      INSERT INTO public.hdc_service_documents (
        id, transaction_id, dispute_id, client_reference, created_by,
        document_type, title, content_text, content_sha256, byte_size
      ) VALUES (
        ${newWorkflowId('DOC')}, ${transactionId}, ${input.disputeId},
        ${input.clientReference}, ${user.id}, ${input.documentType},
        ${input.title}, ${input.content}, ${contentDigest(input.content)},
        ${byteSize}
      )
    `;
    return {
      transaction,
      toolbox: await transactionToolboxPayload(tx, transaction),
      replayed: false,
    };
  });

  if (!result.replayed) {
    await audit(sql, user.id, 'workflow.document.created', 'success', {
      transaction_id: transactionId,
      document_type: input.documentType,
    });
    await notifyTransactionCounterparty(
      sql,
      result.transaction,
      user.id,
      'workflow.document_created',
      'New service document',
      `${input.title} was added to the service workspace.`,
      { transactionId, documentType: input.documentType },
    );
  }
  return json(
    { toolbox: result.toolbox, idempotentReplay: result.replayed },
    result.replayed ? 200 : 201,
  );
}

async function handleRemoveTransactionDocument(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
  documentId: string,
): Promise<Response> {
  if (req.method !== 'DELETE') return methodNotAllowed();
  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    const transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
      true,
    );
    const rows = await tx`
      SELECT * FROM public.hdc_service_documents
      WHERE id = ${documentId}
        AND transaction_id = ${transactionId}
      FOR UPDATE
    `;
    if (rows.length === 0) {
      throw new WorkflowHttpError(
        'document_not_found',
        404,
        'That service document was not found.',
      );
    }
    const document = rowObject(rows[0]);
    if (String(document.created_by) !== user.id) {
      throw new WorkflowHttpError(
        'document_remove_forbidden',
        403,
        'Only the participant who created this document can remove it.',
      );
    }
    if (document.dispute_id !== null && document.dispute_id !== undefined) {
      throw new WorkflowHttpError(
        'dispute_document_immutable',
        409,
        'A document linked to a dispute is retained as case evidence.',
      );
    }
    if (String(document.status) !== 'removed') {
      await tx`
        UPDATE public.hdc_service_documents
        SET status = 'removed'
        WHERE id = ${documentId}
      `;
    }
    return {
      transaction,
      toolbox: await transactionToolboxPayload(tx, transaction),
      replayed: String(document.status) === 'removed',
    };
  });
  if (!result.replayed) {
    await audit(sql, user.id, 'workflow.document.removed', 'success', {
      transaction_id: transactionId,
      document_id: documentId,
    });
  }
  return json({
    toolbox: result.toolbox,
    idempotentReplay: result.replayed,
  });
}

async function handleOpenServiceDispute(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
): Promise<Response> {
  if (req.method !== 'POST') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseDisputeWrite(body);

  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    let transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
      true,
    );
    const replayRows = await tx`
      SELECT * FROM public.hdc_service_disputes
      WHERE transaction_id = ${transactionId}
        AND opened_by = ${user.id}
        AND client_reference = ${input.clientReference}
      LIMIT 1
    `;
    if (replayRows.length > 0) {
      const replay = rowObject(replayRows[0]);
      if (
        String(replay.reason_code) !== input.reasonCode ||
        String(replay.summary) !== input.summary ||
        String(replay.requested_outcome) !== input.requestedOutcome
      ) {
        throw new WorkflowHttpError(
          'dispute_reference_conflict',
          409,
          'That dispute reference is already in use.',
        );
      }
      return {
        transaction,
        toolbox: await transactionToolboxPayload(tx, transaction),
        replayed: true,
      };
    }
    const activeRows = await tx`
      SELECT id FROM public.hdc_service_disputes
      WHERE transaction_id = ${transactionId}
        AND status IN ('open', 'underReview')
      LIMIT 1
    `;
    if (activeRows.length > 0 || String(transaction.status) === 'disputed') {
      throw new WorkflowHttpError(
        'active_dispute_exists',
        409,
        'This transaction already has an active dispute.',
      );
    }

    const disputeId = newWorkflowId('DSP');
    const priorStatus = String(transaction.status);
    await tx`
      INSERT INTO public.hdc_service_disputes (
        id, transaction_id, client_reference, opened_by, reason_code,
        summary, requested_outcome, prior_transaction_status, status
      ) VALUES (
        ${disputeId}, ${transactionId}, ${input.clientReference}, ${user.id},
        ${input.reasonCode}, ${input.summary}, ${input.requestedOutcome},
        ${priorStatus}, 'open'
      )
    `;
    await tx`
      INSERT INTO public.hdc_service_dispute_events (
        id, dispute_id, transaction_id, actor_id, event_type, message
      ) VALUES (
        ${newWorkflowId('DSP-EVT')}, ${disputeId}, ${transactionId},
        ${user.id}, 'opened', ${input.summary}
      )
    `;
    const activity = transactionActivity(
      transaction,
      user.id,
      'disputeOpened',
      'A participant opened a dispute. Service actions are frozen for review.',
      'disputed',
    );
    const transactionRows = await tx`
      UPDATE public.hdc_service_transactions
      SET status = 'disputed', activity = ${tx.json(activity)}
      WHERE id = ${transactionId}
      RETURNING *
    `;
    transaction = rowObject(transactionRows[0]);
    return {
      transaction,
      toolbox: await transactionToolboxPayload(tx, transaction),
      replayed: false,
      disputeId,
    };
  });

  const openedDisputeId = result.disputeId;
  if (!result.replayed && openedDisputeId) {
    await audit(sql, user.id, 'workflow.dispute.opened', 'success', {
      transaction_id: transactionId,
      dispute_id: openedDisputeId,
      reason_code: input.reasonCode,
    });
    await notifyTransactionCounterparty(
      sql,
      result.transaction,
      user.id,
      'workflow.dispute_opened',
      'Service dispute opened',
      'The transaction is frozen while the issue is reviewed.',
      { transactionId, disputeId: openedDisputeId },
      'critical',
    );
  }
  return json(
    { toolbox: result.toolbox, idempotentReplay: result.replayed },
    result.replayed ? 200 : 201,
  );
}

function requestStatusForTransactionStatus(status: string): string {
  if (status === 'completed') return 'completed';
  if (status === 'cancelled') return 'cancelled';
  if (status === 'inProgress' || status === 'awaitingCustomerConfirmation') {
    return 'inProgress';
  }
  return 'technicianSelected';
}

async function handleServiceDisputeParticipantAction(
  req: Request,
  sql: DbClient,
  user: UserView,
  transactionId: string,
  disputeId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseDisputeParticipantActionWrite(body);

  const result = await withWorkflowAuthority(sql, user, async (tx) => {
    let transaction = await transactionForParticipant(
      tx,
      user,
      transactionId,
      true,
    );
    const rows = await tx`
      SELECT * FROM public.hdc_service_disputes
      WHERE id = ${disputeId}
        AND transaction_id = ${transactionId}
      FOR UPDATE
    `;
    if (rows.length === 0) {
      throw new WorkflowHttpError(
        'dispute_not_found',
        404,
        'That dispute was not found.',
      );
    }
    const dispute = rowObject(rows[0]);
    if (!['open', 'underReview'].includes(String(dispute.status))) {
      throw new WorkflowHttpError(
        'dispute_closed',
        409,
        'That dispute is no longer active.',
      );
    }

    if (input.action === 'withdraw') {
      if (String(dispute.opened_by) !== user.id) {
        throw new WorkflowHttpError(
          'dispute_withdraw_forbidden',
          403,
          'Only the participant who opened this dispute can withdraw it.',
        );
      }
      const restoredStatus = String(dispute.prior_transaction_status);
      await tx`
        UPDATE public.hdc_service_disputes
        SET status = 'withdrawn', resolution_note = ${input.message},
            resolved_at = now()
        WHERE id = ${disputeId}
      `;
      const activity = transactionActivity(
        transaction,
        user.id,
        'disputeWithdrawn',
        'The dispute was withdrawn and the previous service state was restored.',
        restoredStatus,
      );
      const transactionRows = await tx`
        UPDATE public.hdc_service_transactions
        SET status = ${restoredStatus}, activity = ${tx.json(activity)}
        WHERE id = ${transactionId}
        RETURNING *
      `;
      await tx`
        UPDATE public.hdc_service_requests
        SET status = ${requestStatusForTransactionStatus(restoredStatus)}
        WHERE id = ${String(transaction.request_id)}
      `;
      transaction = rowObject(transactionRows[0]);
    }

    await tx`
      INSERT INTO public.hdc_service_dispute_events (
        id, dispute_id, transaction_id, actor_id, event_type, message
      ) VALUES (
        ${newWorkflowId('DSP-EVT')}, ${disputeId}, ${transactionId},
        ${user.id},
        ${input.action === 'withdraw' ? 'withdrawn' : 'participantNote'},
        ${input.message}
      )
    `;
    return {
      transaction,
      toolbox: await transactionToolboxPayload(tx, transaction),
      action: input.action,
    };
  });

  await audit(sql, user.id, `workflow.dispute.${result.action}`, 'success', {
    transaction_id: transactionId,
    dispute_id: disputeId,
  });
  await notifyTransactionCounterparty(
    sql,
    result.transaction,
    user.id,
    result.action === 'withdraw'
      ? 'workflow.dispute_withdrawn'
      : 'workflow.dispute_note',
    result.action === 'withdraw' ? 'Dispute withdrawn' : 'Dispute updated',
    result.action === 'withdraw'
      ? 'The other participant withdrew the dispute.'
      : 'The other participant added a note to the dispute.',
    { transactionId, disputeId },
    'high',
  );
  return json({ toolbox: result.toolbox });
}

function requireDisputeResolver(user: UserView): void {
  if (!canApprovePlatformRoles(user.internalRoles)) {
    throw new WorkflowHttpError(
      'dispute_resolution_forbidden',
      403,
      'Owner or Super Admin access is required to resolve disputes.',
    );
  }
}

async function handleInternalDisputes(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  requireDisputeResolver(user);
  const rows = await sql`
    SELECT
      dispute.*,
      transaction.request_title,
      transaction.customer_name,
      transaction.technician_name
    FROM public.hdc_service_disputes dispute
    JOIN public.hdc_service_transactions transaction
      ON transaction.id = dispute.transaction_id
    ORDER BY
      CASE dispute.status WHEN 'open' THEN 0 WHEN 'underReview' THEN 1 ELSE 2 END,
      dispute.created_at DESC
    LIMIT 200
  `;
  const eventRows = await sql`
    SELECT * FROM public.hdc_service_dispute_events
    WHERE dispute_id IN (
      SELECT id FROM public.hdc_service_disputes
      ORDER BY created_at DESC
      LIMIT 200
    )
    ORDER BY created_at, id
  `;
  return json({
    disputes: rows.map((row) => ({
      ...disputeView(rowObject(row)),
      requestTitle: String(row.request_title),
      customerName: String(row.customer_name),
      technicianName: String(row.technician_name),
    })),
    events: eventRows.map((row) => disputeEventView(rowObject(row))),
    openCount: rows.filter((row) =>
      ['open', 'underReview'].includes(String(row.status))).length,
    updatedAt: new Date().toISOString(),
  });
}

async function handleInternalDisputeResolution(
  req: Request,
  sql: DbClient,
  user: UserView,
  disputeId: string,
): Promise<Response> {
  if (req.method !== 'PUT') return methodNotAllowed();
  requireDisputeResolver(user);
  const body = await readJson(req);
  if (!body) return json({ error: 'invalid_json' }, 400);
  const input = parseDisputeResolutionWrite(body);

  const result = await sql.begin(async (tx) => {
    const rows = await tx`
      SELECT dispute.*, transaction.activity, transaction.request_id,
             transaction.customer_id, transaction.technician_id,
             transaction.status AS transaction_status
      FROM public.hdc_service_disputes dispute
      JOIN public.hdc_service_transactions transaction
        ON transaction.id = dispute.transaction_id
      WHERE dispute.id = ${disputeId}
      FOR UPDATE OF dispute, transaction
    `;
    if (rows.length === 0) {
      throw new WorkflowHttpError(
        'dispute_not_found',
        404,
        'That dispute was not found.',
      );
    }
    const dispute = rowObject(rows[0]);
    if (!['open', 'underReview'].includes(String(dispute.status))) {
      throw new WorkflowHttpError(
        'dispute_closed',
        409,
        'That dispute has already been closed.',
      );
    }
    const restoresPrior = ['serviceContinues', 'noAdjustment', 'other']
      .includes(input.outcome);
    const targetStatus = restoresPrior
      ? String(dispute.prior_transaction_status)
      : targetStatusForDisputeOutcome(input.outcome);
    const transactionShape: Record<string, unknown> = {
      ...dispute,
      id: dispute.transaction_id,
      status: dispute.transaction_status,
      activity: dispute.activity,
    };
    const activity = transactionActivity(
      transactionShape,
      user.id,
      'disputeResolved',
      `Dispute resolved: ${input.outcome}. ${input.note}`,
      targetStatus,
    );
    if (String(dispute.status) === 'open') {
      await tx`
        INSERT INTO public.hdc_service_dispute_events (
          id, dispute_id, transaction_id, actor_id, event_type, message
        ) VALUES (
          ${newWorkflowId('DSP-EVT')}, ${disputeId},
          ${String(dispute.transaction_id)}, ${user.id}, 'reviewStarted',
          'Owner review started.'
        )
      `;
    }
    await tx`
      UPDATE public.hdc_service_disputes
      SET status = 'resolved', resolution_outcome = ${input.outcome},
          resolution_note = ${input.note}, resolved_by = ${user.id},
          resolved_at = now()
      WHERE id = ${disputeId}
    `;
    await tx`
      INSERT INTO public.hdc_service_dispute_events (
        id, dispute_id, transaction_id, actor_id, event_type, message
      ) VALUES (
        ${newWorkflowId('DSP-EVT')}, ${disputeId},
        ${String(dispute.transaction_id)}, ${user.id}, 'resolved',
        ${`${input.outcome}: ${input.note}`}
      )
    `;
    await tx`
      UPDATE public.hdc_service_transactions
      SET status = ${targetStatus}, activity = ${tx.json(activity)}
      WHERE id = ${String(dispute.transaction_id)}
    `;
    await tx`
      UPDATE public.hdc_service_requests
      SET status = ${requestStatusForTransactionStatus(targetStatus)}
      WHERE id = ${String(dispute.request_id)}
    `;
    await tx`
      UPDATE public.hdc_service_transaction_exceptions
      SET status = 'resolved', resolved_at = now()
      WHERE transaction_id = ${String(dispute.transaction_id)}
        AND status = 'underReview'
    `;
    return {
      transactionId: String(dispute.transaction_id),
      customerId: String(dispute.customer_id),
      technicianId: String(dispute.technician_id),
      targetStatus,
    };
  });

  await audit(sql, user.id, 'workflow.dispute.resolved', 'success', {
    dispute_id: disputeId,
    transaction_id: result.transactionId,
    outcome: input.outcome,
  });
  const notificationMetadata = {
    transactionId: result.transactionId,
    disputeId,
    outcome: input.outcome,
  };
  await Promise.all([
    notifyUser(
      sql,
      result.customerId,
      'workflow.dispute_resolved',
      'Dispute resolved',
      `The dispute outcome is ${input.outcome}. Review the resolution note.`,
      notificationMetadata,
      'critical',
    ),
    notifyUser(
      sql,
      result.technicianId,
      'workflow.dispute_resolved',
      'Dispute resolved',
      `The dispute outcome is ${input.outcome}. Review the resolution note.`,
      notificationMetadata,
      'critical',
    ),
  ]);
  return json({
    resolved: true,
    disputeId,
    transactionId: result.transactionId,
    transactionStatus: result.targetStatus,
  });
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

async function handleTechnicianOpportunities(
  req: Request,
  sql: DbClient,
  user: UserView,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  requireWorkflowRole(user, 'technician');

  const requests = await withWorkflowAuthority(sql, user, async (tx) => {
    return await tx`
      SELECT *
      FROM public.hdc_service_requests
      WHERE status IN ('open', 'receivingOffers')
        AND customer_id <> ${user.id}
      ORDER BY created_at DESC
    `;
  });

  return json({
    serviceRequests: requests.map((row) =>
      serviceRequestView(rowObject(row))),
    updatedAt: new Date().toISOString(),
  });
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
      ON CONFLICT (id) DO NOTHING
      RETURNING *
    `;
    if (rows.length > 0) {
      return {
        serviceRequest: serviceRequestView(rowObject(rows[0])),
        replayed: false,
      };
    }

    const existingRows = await tx`
      SELECT *
      FROM public.hdc_service_requests
      WHERE id = ${input.id}
      LIMIT 1
    `;
    if (
      existingRows.length === 0 ||
      !serviceRequestWriteMatchesRow(
        rowObject(existingRows[0]),
        input,
        user.id,
      )
    ) {
      throw new WorkflowHttpError(
        'service_request_identifier_conflict',
        409,
        'That request identifier is already in use.',
      );
    }
    return {
      serviceRequest: serviceRequestView(rowObject(existingRows[0])),
      replayed: true,
    };
  });

  await audit(sql, user.id, 'workflow.request.create', 'success', {
    request_id: input.id,
    idempotent_replay: created.replayed,
  });
  return json(
    {
      serviceRequest: created.serviceRequest,
      idempotentReplay: created.replayed,
    },
    created.replayed ? 200 : 201,
  );
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
      SELECT id, customer_id, status
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
    if (String(requestRows[0].customer_id) === user.id) {
      throw new WorkflowHttpError(
        'self_proposal_not_allowed',
        409,
        'You cannot submit a technician proposal to your own service request.',
      );
    }

    const existingProposalRows = await tx`
      SELECT *
      FROM public.hdc_proposals
      WHERE request_id = ${input.requestId}
        AND technician_id = ${user.id}
      FOR UPDATE
    `;
    if (existingProposalRows.length > 0) {
      const existingProposal = rowObject(existingProposalRows[0]);
      if (
        proposalWriteMatchesRow(
          existingProposal,
          input,
          user.id,
          score,
        )
      ) {
        const existingRequestRows = await tx`
          SELECT *
          FROM public.hdc_service_requests
          WHERE id = ${input.requestId}
          LIMIT 1
        `;
        return {
          proposal: proposalView(existingProposal),
          updatedRequest: serviceRequestView(
            rowObject(existingRequestRows[0]),
          ),
          replayed: true,
        };
      }
      throw new WorkflowHttpError(
        'proposal_already_exists',
        409,
        'You already have a proposal for this request. Refresh it before editing.',
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
      replayed: false,
    };
  });

  await audit(sql, user.id, 'workflow.proposal.create', 'success', {
    proposal_id: String(created.proposal.id),
    client_proposal_id: input.id,
    request_id: input.requestId,
    status: input.status,
    idempotent_replay: created.replayed,
  });
  if (input.status === 'submitted' && !created.replayed) {
    const request = created.updatedRequest as Record<string, unknown>;
    await notifyUser(
      sql,
      String(request.customerId),
      'workflow.proposal_received',
      'New service proposal',
      'A technician submitted an offer for your service request.',
      {
        requestId: input.requestId,
        proposalId: String((created.proposal as Record<string, unknown>).id),
      },
      'high',
    );
  }
  return json({
    proposal: created.proposal,
    updatedRequest: created.updatedRequest,
    idempotentReplay: created.replayed,
  }, created.replayed ? 200 : 201);
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
        replayed: true,
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
      replayed: false,
    };
  });

  await audit(sql, user.id, 'workflow.proposal.accept', 'success', {
    proposal_id: proposalId,
    request_id: String((result.updatedRequest as Record<string, unknown>).id),
    transaction_id: String((result.serviceTransaction as Record<string, unknown>).id),
  });
  if (result.replayed !== true) {
    const accepted = result.acceptedProposal as Record<string, unknown>;
    const transaction = result.serviceTransaction as Record<string, unknown>;
    await notifyUser(
      sql,
      String(accepted.technicianId),
      'workflow.proposal_accepted',
      'Proposal accepted',
      'Your proposal was accepted and a service workspace is now active.',
      {
        proposalId,
        transactionId: String(transaction.id),
      },
      'high',
    );
    for (const competingValue of result.competingProposals as unknown[]) {
      const competing = competingValue as Record<string, unknown>;
      await notifyUser(
        sql,
        String(competing.technicianId),
        'workflow.proposal_closed',
        'Service request assigned',
        'The customer selected another proposal for this service request.',
        {
          proposalId: String(competing.id),
          transactionId: String(transaction.id),
        },
      );
    }
  }
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
  if (nextStatus === 'disputed') {
    throw new WorkflowHttpError(
      'dispute_record_required',
      409,
      'Open a dispute from the service workspace so the reason is recorded.',
    );
  }
  if (nextStatus === 'cancelled') {
    throw new WorkflowHttpError(
      'cancellation_record_required',
      409,
      'Cancel from the service workspace so the reason is recorded.',
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
  await notifyTransactionCounterparty(
    sql,
    updated.serviceTransaction as Record<string, unknown>,
    user.id,
    'workflow.transaction_status_changed',
    'Service status updated',
    `The service transaction is now ${nextStatus}.`,
    { transactionId, status: nextStatus },
  );
  return json(updated);
}

async function handleReadiness(req: Request): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  let sql: DbClient | null = null;
  try {
    sql = openDb();
    const database = await checkDbReadiness(sql);
    if (!database.ready) {
      return json({ service: 'hdc-beta-api', status: 'not_ready' }, 503);
    }
    const authorityRows = await sql`
      SELECT
        to_regclass('public.hdc_service_requests') IS NOT NULL
          AS workflow_table_ready,
        (
          to_regclass('public.hdc_private_conversations') IS NOT NULL AND
          to_regclass('public.hdc_private_messages') IS NOT NULL
        ) AS private_messaging_tables_ready,
        (
          to_regclass('public.hdc_service_schedule_changes') IS NOT NULL AND
          to_regclass('public.hdc_service_change_orders') IS NOT NULL AND
          to_regclass('public.hdc_service_transaction_exceptions') IS NOT NULL AND
          to_regclass('public.hdc_service_payments') IS NOT NULL AND
          to_regclass('public.hdc_service_receipts') IS NOT NULL AND
          to_regclass('public.hdc_service_documents') IS NOT NULL AND
          to_regclass('public.hdc_service_disputes') IS NOT NULL AND
          EXISTS (
            SELECT 1 FROM public.hdc_schema_migrations
            WHERE version = '0015'
          )
        ) AS transaction_tools_ready,
        (
          to_regclass('public.hdc_users') IS NOT NULL AND
          to_regclass('public.hdc_user_roles') IS NOT NULL AND
          to_regclass('public.hdc_auth_sessions') IS NOT NULL AND
          to_regclass('public.hdc_security_audit') IS NOT NULL AND
          EXISTS (
            SELECT 1 FROM public.hdc_schema_migrations
            WHERE version = '0000'
          )
        ) AS auth_bootstrap_ready,
        (
          to_regclass('public.hdc_legal_documents') IS NOT NULL AND
          to_regclass('public.hdc_privacy_requests') IS NOT NULL AND
          EXISTS (
            SELECT 1 FROM public.hdc_schema_migrations
            WHERE version = '0016'
          ) AND
          EXISTS (
            SELECT 1 FROM public.hdc_legal_documents
            WHERE document_type = 'terms_of_service'
              AND document_version = ${CURRENT_LEGAL_VERSION}
              AND content_sha256 = ${CURRENT_LEGAL_DOCUMENTS.terms_of_service.contentSha256}
              AND status = 'published'
          ) AND
          EXISTS (
            SELECT 1 FROM public.hdc_legal_documents
            WHERE document_type = 'privacy_notice'
              AND document_version = ${CURRENT_LEGAL_VERSION}
              AND content_sha256 = ${CURRENT_LEGAL_DOCUMENTS.privacy_notice.contentSha256}
              AND status = 'published'
          )
        ) AS legal_records_ready,
        EXISTS (
          SELECT 1
          FROM pg_roles
          WHERE rolname = 'hdc_app'
            AND pg_has_role(current_user, oid, 'SET')
        ) AS workflow_role_ready,
        EXISTS (
          SELECT 1
          FROM pg_policies
          WHERE schemaname = 'public'
            AND tablename = 'hdc_service_requests'
            AND policyname = 'hdc_service_requests_technician_lock'
            AND cmd = 'UPDATE'
        ) AS technician_proposal_lock_ready
    `;
    const authority = rowObject(authorityRows[0]);
    const workflowAuthorityReady =
      authority.workflow_table_ready === true &&
      authority.private_messaging_tables_ready === true &&
      authority.transaction_tools_ready === true &&
      authority.auth_bootstrap_ready === true &&
      authority.legal_records_ready === true &&
      authority.workflow_role_ready === true &&
      authority.technician_proposal_lock_ready === true;
    if (!workflowAuthorityReady) {
      return json({
        service: 'hdc-beta-api',
        status: 'not_ready',
        error: 'workflow_authority_unavailable',
        checks: {
          database: 'ok',
          workflowAuthority: 'not_ready',
          privateMessaging:
            authority.private_messaging_tables_ready === true
              ? 'ok'
              : 'not_ready',
          transactionTools:
            authority.transaction_tools_ready === true ? 'ok' : 'not_ready',
          authBootstrap:
            authority.auth_bootstrap_ready === true ? 'ok' : 'not_ready',
          legalRecords:
            authority.legal_records_ready === true ? 'ok' : 'not_ready',
        },
      }, 503);
    }
    return json({
      service: 'hdc-beta-api',
      status: 'ready',
      checks: {
        database: 'ok',
        workflowAuthority: 'ok',
        privateMessaging: 'ok',
        transactionTools: 'ok',
        authBootstrap: 'ok',
        legalRecords: 'ok',
      },
      latencyMs: database.latencyMs,
    });
  } catch (error) {
    console.warn(
      'HDC readiness check failed',
      error instanceof Error ? error.message : 'unknown_error',
    );
    return json({ service: 'hdc-beta-api', status: 'not_ready' }, 503);
  } finally {
    if (sql) {
      try {
        await closeDb(sql);
      } catch {
        // A failed readiness connection may already be closed by the driver.
      }
    }
  }
}

async function handleHdcApiRequestCore(
  req: Request,
  requestReference: string,
): Promise<Response> {
  const path = new URL(req.url).pathname;
  if (path === '/api/health') {
    if (req.method !== 'GET') return methodNotAllowed();
    return json({
      service: 'hdc-beta-api',
      status: 'ok',
      build: '0.6.4-build24',
    });
  }
  if (path === '/api/health/ready') return await handleReadiness(req);
  if (path === '/api/legal/documents') return await handleLegalDocuments(req);

  const operation = operationDecision(operationMode(), req.method, path);
  if (!operation.allowed) {
    return json(
      {
        error: operation.errorCode,
        message: 'HDC is temporarily limiting operations. Please try again later.',
        referenceId: requestReference,
      },
      503,
      { 'retry-after': String(operation.retryAfterSeconds ?? 300) },
    );
  }

  const isRolePath =
    path === '/api/roles/overview' ||
    path === '/api/role-applications';

  const isInternalPath =
    path === '/api/internal/dashboard' ||
    path === '/api/internal/role-applications' ||
    path.startsWith('/api/internal/role-applications/') ||
    path === '/api/internal/account-recovery' ||
    path.startsWith('/api/internal/account-recovery/') ||
    path === '/api/internal/disputes' ||
    path.startsWith('/api/internal/disputes/') ||
    path === '/api/internal/privacy-requests' ||
    path.startsWith('/api/internal/privacy-requests/');

  const isPrivacyPath = path === '/api/privacy/requests';

  const isNotificationPath =
    path === '/api/notifications' ||
    path === '/api/notifications/read-all' ||
    path.startsWith('/api/notifications/');

  const isProfilePath =
    path === '/api/profiles' ||
    path === '/api/profiles/member' ||
    path.startsWith('/api/profiles/');

  const isDiscoveryPath =
    path === '/api/discovery/technicians' ||
    path === '/api/discovery/opportunities';

  const isCommercePath =
    path === '/api/commerce/catalog' ||
    path === '/api/commerce/buyer-dashboard' ||
    path === '/api/commerce/seller-dashboard' ||
    path === '/api/commerce/listings' ||
    path.startsWith('/api/commerce/listings/') ||
    path === '/api/commerce/purchase-requests' ||
    path.startsWith('/api/commerce/purchase-requests/');

  const isWorkflowPath =
    path === '/api/workflow/bootstrap' ||
    path === '/api/service-requests' ||
    path.startsWith('/api/service-requests/') ||
    path === '/api/proposals' ||
    path.startsWith('/api/proposals/') ||
    path.startsWith('/api/service-transactions/');

  if (path === '/api/auth/recovery/start') {
    return await handleRecoveryStart(req);
  }

  let sql: DbClient | null = null;
  try {
    sql = openDb();
    if (path === '/api/auth/register') return await handleRegister(req, sql);
    if (path === '/api/auth/login') return await handleLogin(req, sql);
    if (path === '/api/auth/session') return await handleSession(req, sql);
    if (path === '/api/auth/logout') return await handleLogout(req, sql);
    if (path === '/api/legal/acceptance') {
      return await handleLegalAcceptance(req, sql);
    }
    if (path === '/api/auth/recovery/verify') {
      return await handleRecoveryVerify(req, sql);
    }
    if (path === '/api/auth/recovery/reset') {
      return await handlePasswordReset(req, sql);
    }
    if (path === '/api/auth/password-reset/confirm') {
      return await handlePasswordReset(req, sql);
    }
    if (path === '/api/auth/recovery/answers') {
      const session = await activeSession(req, sql);
      if (!session) return json({ error: 'unauthorized' }, 401);
      return await handleUpdateRecoveryAnswers(req, sql, session.user);
    }

    if (path === '/api/commerce/catalog') {
      return await handleProductCatalog(req, sql);
    }

    if (isPrivacyPath) {
      const session = await activeSession(req, sql);
      if (!session) return json({ error: 'unauthorized' }, 401);
      return await handlePrivacyRequests(req, sql, session.user);
    }

    if (isNotificationPath) {
      const session = await activeSession(req, sql);
      if (!session) return json({ error: 'unauthorized' }, 401);
      if (path === '/api/notifications') {
        return await handleNotificationCenter(req, sql, session.user);
      }
      if (path === '/api/notifications/read-all') {
        return await handleNotificationsReadAll(req, sql, session.user);
      }
      const notificationReadMatch =
        /^\/api\/notifications\/([^/]+)\/read$/.exec(path);
      if (notificationReadMatch) {
        return await handleNotificationRead(
          req,
          sql,
          session.user,
          requirePathId(notificationReadMatch[1]),
        );
      }
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

    if (isDiscoveryPath) {
      const session = await activeSession(req, sql);
      if (!session) return json({ error: 'unauthorized' }, 401);

      if (path === '/api/discovery/technicians') {
        return await handleTechnicianDirectory(req, sql);
      }
      if (path === '/api/discovery/opportunities') {
        return await handleTechnicianOpportunities(req, sql, session.user);
      }
    }

    if (isCommercePath) {
      const session = await activeSession(req, sql);
      if (!session) return json({ error: 'unauthorized' }, 401);

      if (path === '/api/commerce/seller-dashboard') {
        return await handleSellerDashboard(req, sql, session.user);
      }
      if (path === '/api/commerce/buyer-dashboard') {
        return await handleBuyerDashboard(req, sql, session.user);
      }
      if (path === '/api/commerce/listings') {
        return await handleCreateProductListing(req, sql, session.user);
      }
      if (path === '/api/commerce/purchase-requests') {
        return await handleCreateProductPurchaseRequest(
          req,
          sql,
          session.user,
        );
      }

      const purchaseRequestMatch =
        /^\/api\/commerce\/purchase-requests\/([^/]+)\/status$/.exec(path);
      if (purchaseRequestMatch) {
        return await handleProductPurchaseRequestAction(
          req,
          sql,
          session.user,
          requirePathId(purchaseRequestMatch[1]),
        );
      }

      const listingMatch = /^\/api\/commerce\/listings\/([^/]+)$/.exec(path);
      if (listingMatch) {
        return await handleUpdateProductListing(
          req,
          sql,
          session.user,
          requirePathId(listingMatch[1]),
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
      if (path === '/api/internal/disputes') {
        return await handleInternalDisputes(req, sql, session.user);
      }
      if (path === '/api/internal/privacy-requests') {
        return await handleInternalPrivacyRequests(req, sql, session.user);
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

      const disputeResolutionMatch =
        /^\/api\/internal\/disputes\/([^/]+)$/.exec(path);
      if (disputeResolutionMatch) {
        return await handleInternalDisputeResolution(
          req,
          sql,
          session.user,
          requirePathId(disputeResolutionMatch[1]),
        );
      }

      const privacyRequestReviewMatch =
        /^\/api\/internal\/privacy-requests\/([^/]+)$/.exec(path);
      if (privacyRequestReviewMatch) {
        return await handleInternalPrivacyRequestReview(
          req,
          sql,
          session.user,
          requirePathId(privacyRequestReviewMatch[1]),
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

      const privateMessageMatch =
        /^\/api\/service-transactions\/([^/]+)\/conversation\/messages$/.exec(
          path,
        );
      if (privateMessageMatch) {
        return await handleSendPrivateMessage(
          req,
          sql,
          session.user,
          requirePathId(privateMessageMatch[1]),
        );
      }

      const privateReadMatch =
        /^\/api\/service-transactions\/([^/]+)\/conversation\/read$/.exec(
          path,
        );
      if (privateReadMatch) {
        return await handleMarkPrivateConversationRead(
          req,
          sql,
          session.user,
          requirePathId(privateReadMatch[1]),
        );
      }

      const privateStorageMatch =
        /^\/api\/service-transactions\/([^/]+)\/conversation\/storage$/.exec(
          path,
        );
      if (privateStorageMatch) {
        return await handlePrivateConversationStorage(
          req,
          sql,
          session.user,
          requirePathId(privateStorageMatch[1]),
        );
      }

      const privateConversationMatch =
        /^\/api\/service-transactions\/([^/]+)\/conversation$/.exec(path);
      if (privateConversationMatch) {
        return await handlePrivateConversation(
          req,
          sql,
          session.user,
          requirePathId(privateConversationMatch[1]),
        );
      }

      const transactionToolboxMatch =
        /^\/api\/service-transactions\/([^/]+)\/toolbox$/.exec(path);
      if (transactionToolboxMatch) {
        return await handleTransactionToolbox(
          req,
          sql,
          session.user,
          requirePathId(transactionToolboxMatch[1]),
        );
      }

      const scheduleDecisionMatch =
        /^\/api\/service-transactions\/([^/]+)\/schedule-changes\/([^/]+)$/.exec(
          path,
        );
      if (scheduleDecisionMatch) {
        return await handleScheduleChangeDecision(
          req,
          sql,
          session.user,
          requirePathId(scheduleDecisionMatch[1]),
          requirePathId(scheduleDecisionMatch[2]),
        );
      }
      const scheduleCollectionMatch =
        /^\/api\/service-transactions\/([^/]+)\/schedule-changes$/.exec(path);
      if (scheduleCollectionMatch) {
        return await handleCreateScheduleChange(
          req,
          sql,
          session.user,
          requirePathId(scheduleCollectionMatch[1]),
        );
      }

      const changeOrderDecisionMatch =
        /^\/api\/service-transactions\/([^/]+)\/change-orders\/([^/]+)$/.exec(
          path,
        );
      if (changeOrderDecisionMatch) {
        return await handleChangeOrderDecision(
          req,
          sql,
          session.user,
          requirePathId(changeOrderDecisionMatch[1]),
          requirePathId(changeOrderDecisionMatch[2]),
        );
      }
      const changeOrderCollectionMatch =
        /^\/api\/service-transactions\/([^/]+)\/change-orders$/.exec(path);
      if (changeOrderCollectionMatch) {
        return await handleCreateChangeOrder(
          req,
          sql,
          session.user,
          requirePathId(changeOrderCollectionMatch[1]),
        );
      }

      const exceptionCollectionMatch =
        /^\/api\/service-transactions\/([^/]+)\/exceptions$/.exec(path);
      if (exceptionCollectionMatch) {
        return await handleCreateTransactionException(
          req,
          sql,
          session.user,
          requirePathId(exceptionCollectionMatch[1]),
        );
      }

      const paymentActionMatch =
        /^\/api\/service-transactions\/([^/]+)\/payments\/([^/]+)$/.exec(path);
      if (paymentActionMatch) {
        return await handleServicePaymentAction(
          req,
          sql,
          session.user,
          requirePathId(paymentActionMatch[1]),
          requirePathId(paymentActionMatch[2]),
        );
      }
      const paymentCollectionMatch =
        /^\/api\/service-transactions\/([^/]+)\/payments$/.exec(path);
      if (paymentCollectionMatch) {
        return await handleCreateServicePayment(
          req,
          sql,
          session.user,
          requirePathId(paymentCollectionMatch[1]),
        );
      }

      const documentActionMatch =
        /^\/api\/service-transactions\/([^/]+)\/documents\/([^/]+)$/.exec(path);
      if (documentActionMatch) {
        return await handleRemoveTransactionDocument(
          req,
          sql,
          session.user,
          requirePathId(documentActionMatch[1]),
          requirePathId(documentActionMatch[2]),
        );
      }
      const documentCollectionMatch =
        /^\/api\/service-transactions\/([^/]+)\/documents$/.exec(path);
      if (documentCollectionMatch) {
        return await handleCreateTransactionDocument(
          req,
          sql,
          session.user,
          requirePathId(documentCollectionMatch[1]),
        );
      }

      const disputeActionMatch =
        /^\/api\/service-transactions\/([^/]+)\/disputes\/([^/]+)$/.exec(path);
      if (disputeActionMatch) {
        return await handleServiceDisputeParticipantAction(
          req,
          sql,
          session.user,
          requirePathId(disputeActionMatch[1]),
          requirePathId(disputeActionMatch[2]),
        );
      }
      const disputeCollectionMatch =
        /^\/api\/service-transactions\/([^/]+)\/disputes$/.exec(path);
      if (disputeCollectionMatch) {
        return await handleOpenServiceDispute(
          req,
          sql,
          session.user,
          requirePathId(disputeCollectionMatch[1]),
        );
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
      console.warn('HDC workflow request rejected', {
        referenceId: requestReference,
        method: req.method,
        path,
        code: error.code,
        statusCode: error.statusCode,
      });
      return json({
        error: error.code,
        message: error.message,
        referenceId: requestReference,
      }, error.statusCode);
    }

    const databaseCode = typeof error === 'object' && error !== null && 'code' in error
      ? String((error as { code?: unknown }).code ?? '')
      : '';
    if (databaseCode === '23505') {
      return json({
        error: isProfilePath || isDiscoveryPath
          ? 'profile_conflict'
          : isCommercePath
            ? 'commerce_conflict'
            : 'workflow_conflict',
        referenceId: requestReference,
      }, 409);
    }
    if (databaseCode === '23503' || databaseCode === '23514') {
      return json({
        error: isProfilePath || isDiscoveryPath
          ? 'invalid_profile_relationship'
          : isCommercePath
            ? 'invalid_commerce_relationship'
          : isInternalPath
            ? 'invalid_internal_relationship'
            : 'invalid_workflow_relationship',
        referenceId: requestReference,
      }, 409);
    }
    if (databaseCode === '42P01' || databaseCode === '42704') {
      return json({
        error: isProfilePath || isDiscoveryPath
          ? 'profile_backend_not_ready'
          : isCommercePath
            ? 'commerce_backend_not_ready'
          : isInternalPath
            ? 'internal_backend_not_ready'
          : isRolePath
            ? 'role_backend_not_ready'
            : 'workflow_backend_not_ready',
        referenceId: requestReference,
      }, 503);
    }

    if (
      databaseCode === '42501' &&
      (isWorkflowPath || isDiscoveryPath || isPrivacyPath)
    ) {
      console.error('HDC workflow authority unavailable', {
        referenceId: requestReference,
        method: req.method,
        path,
        databaseCode,
      });
      return json({
        error: 'workflow_authority_unavailable',
        message: 'HDC request services are temporarily unavailable.',
        referenceId: requestReference,
      }, 503);
    }

    console.error('Unhandled HDC API error', {
      referenceId: requestReference,
      method: req.method,
      path,
      databaseCode: databaseCode || null,
      message: error instanceof Error ? error.message : 'unknown_error',
    });
    return json({
      error: 'internal_error',
      referenceId: requestReference,
    }, 500);
  } finally {
    if (sql) {
      try {
        await closeDb(sql);
      } catch (error) {
        console.warn(
          'HDC database close failed',
          error instanceof Error ? error.message : 'unknown_error',
        );
      }
    }
  }
}

function withRequestReference(
  response: Response,
  requestReference: string,
): Response {
  const headers = new Headers(response.headers);
  headers.set('x-hdc-request-id', requestReference);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export async function handleHdcApiRequest(
  req: Request,
  requestReference: string = randomUUID(),
): Promise<Response> {
  const response = req.method === 'OPTIONS'
    ? corsPreflightResponse(req)
    : withCors(req, await handleHdcApiRequestCore(req, requestReference));
  return withRequestReference(response, requestReference);
}

export default async (req: Request, context: Context): Promise<Response> =>
  await handleHdcApiRequest(req, context.requestId);

export const config: Config = {
  path: [
    '/api/health',
    '/api/health/ready',
    '/api/legal/documents',
    '/api/legal/acceptance',
    '/api/auth/register',
    '/api/auth/login',
    '/api/auth/session',
    '/api/auth/logout',
    '/api/auth/recovery/start',
    '/api/auth/recovery/verify',
    '/api/auth/recovery/reset',
    '/api/auth/recovery/answers',
    '/api/auth/password-reset/confirm',
    '/api/roles/overview',
    '/api/role-applications',
    '/api/internal/dashboard',
    '/api/internal/role-applications',
    '/api/internal/role-applications/:id',
    '/api/internal/account-recovery',
    '/api/internal/account-recovery/:id',
    '/api/internal/disputes',
    '/api/internal/disputes/:id',
    '/api/internal/privacy-requests',
    '/api/internal/privacy-requests/:id',
    '/api/privacy/requests',
    '/api/notifications',
    '/api/notifications/read-all',
    '/api/notifications/:id/read',
    '/api/profiles',
    '/api/profiles/member',
    '/api/profiles/:role',
    '/api/discovery/technicians',
    '/api/discovery/opportunities',
    '/api/commerce/catalog',
    '/api/commerce/buyer-dashboard',
    '/api/commerce/seller-dashboard',
    '/api/commerce/listings',
    '/api/commerce/listings/:id',
    '/api/commerce/purchase-requests',
    '/api/commerce/purchase-requests/:id/status',
    '/api/workflow/bootstrap',
    '/api/service-requests',
    '/api/service-requests/:id',
    '/api/proposals',
    '/api/proposals/:id',
    '/api/proposals/:id/accept',
    '/api/service-transactions/:id/status',
    '/api/service-transactions/:id/toolbox',
    '/api/service-transactions/:id/schedule-changes',
    '/api/service-transactions/:id/schedule-changes/:itemId',
    '/api/service-transactions/:id/change-orders',
    '/api/service-transactions/:id/change-orders/:itemId',
    '/api/service-transactions/:id/exceptions',
    '/api/service-transactions/:id/payments',
    '/api/service-transactions/:id/payments/:itemId',
    '/api/service-transactions/:id/documents',
    '/api/service-transactions/:id/documents/:itemId',
    '/api/service-transactions/:id/disputes',
    '/api/service-transactions/:id/disputes/:itemId',
    '/api/service-transactions/:id/conversation',
    '/api/service-transactions/:id/conversation/messages',
    '/api/service-transactions/:id/conversation/read',
    '/api/service-transactions/:id/conversation/storage',
  ],
};
