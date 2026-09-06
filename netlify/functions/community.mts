import { openDb, closeDb, type DbClient } from './_lib/db.mjs';
import { corsPreflightResponse, withCors } from './_lib/cors.mjs';
import { json, methodNotAllowed, readJson } from './_lib/http.mjs';
import { operationMode } from './_lib/env.mjs';
import { authorizeMemberRequest } from './_lib/member-auth.mjs';

const suggestionCategories = new Set([
  'feature', 'usability', 'marketplace', 'service_workflow',
  'safety', 'knowledge_base', 'other',
]);

function cleanText(value: unknown, max: number): string {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\r\n/g, '\n').slice(0, max);
}

function ratingView(row: Record<string, unknown>) {
  return {
    id: String(row.id),
    publicRatingId: String(row.public_rating_id),
    transactionKind: String(row.transaction_kind),
    score: Number(row.score),
    review: String(row.review ?? ''),
    status: String(row.status),
    createdAt: String(row.created_at),
  };
}

async function ratingsView(sql: DbClient, userId: string): Promise<Response> {
  const service = await sql`
    SELECT
      transaction.id, transaction.request_title, transaction.category_name,
      transaction.status,
      CASE WHEN transaction.customer_id = ${userId}::uuid
        THEN transaction.technician_name ELSE transaction.customer_name END AS counterparty_name,
      rating.id AS rating_id, rating.public_rating_id, rating.score,
      rating.review, rating.status AS rating_status, rating.created_at AS rating_created_at
    FROM public.hdc_service_transactions transaction
    LEFT JOIN public.hdc_transaction_ratings rating
      ON rating.service_transaction_id = transaction.id
     AND rating.rater_member_id = ${userId}::uuid
    WHERE transaction.status = 'completed'
      AND ${userId}::uuid IN (transaction.customer_id, transaction.technician_id)
    ORDER BY transaction.updated_at DESC
    LIMIT 100
  `;
  const commerce = await sql`
    SELECT
      purchase.id, purchase.public_purchase_id, purchase.listing_title_snapshot,
      purchase.status, purchase.version,
      CASE WHEN purchase.buyer_user_id = ${userId}::uuid
        THEN purchase.seller_name_snapshot ELSE purchase.buyer_name_snapshot END AS counterparty_name,
      purchase.buyer_user_id = ${userId}::uuid AS is_buyer,
      purchase.seller_user_id = ${userId}::uuid AS is_seller,
      rating.id AS rating_id, rating.public_rating_id, rating.score,
      rating.review, rating.status AS rating_status, rating.created_at AS rating_created_at
    FROM public.hdc_product_purchase_requests purchase
    LEFT JOIN public.hdc_transaction_ratings rating
      ON rating.purchase_request_id = purchase.id
     AND rating.rater_member_id = ${userId}::uuid
    WHERE purchase.status IN ('accepted', 'fulfilled', 'completed')
      AND ${userId}::uuid IN (purchase.buyer_user_id, purchase.seller_user_id)
    ORDER BY purchase.updated_at DESC
    LIMIT 100
  `;
  const received = await sql`
    SELECT count(*)::integer AS rating_count,
           COALESCE(round(avg(score)::numeric, 2), 0) AS average_score
    FROM public.hdc_transaction_ratings
    WHERE rated_member_id = ${userId}::uuid AND status = 'active'
  `;
  return json({
    received: {
      count: Number(received[0]?.rating_count ?? 0),
      average: Number(received[0]?.average_score ?? 0),
    },
    service: service.map((row) => ({
      transactionKind: 'service',
      transactionId: String(row.id),
      title: String(row.request_title),
      subtitle: String(row.category_name),
      counterpartyName: String(row.counterparty_name),
      status: String(row.status),
      canRate: row.rating_id == null,
      rating: row.rating_id == null ? null : ratingView({
        id: row.rating_id,
        public_rating_id: row.public_rating_id,
        transaction_kind: 'service',
        score: row.score,
        review: row.review,
        status: row.rating_status,
        created_at: row.rating_created_at,
      }),
    })),
    commerce: commerce.map((row) => ({
      transactionKind: 'commerce',
      transactionId: String(row.id),
      publicPurchaseId: String(row.public_purchase_id),
      title: String(row.listing_title_snapshot),
      counterpartyName: String(row.counterparty_name),
      status: String(row.status),
      version: Number(row.version),
      canMarkFulfilled: Boolean(row.is_seller) && row.status === 'accepted',
      canConfirmComplete: Boolean(row.is_buyer) && row.status === 'fulfilled',
      canRate: row.status === 'completed' && row.rating_id == null,
      rating: row.rating_id == null ? null : ratingView({
        id: row.rating_id,
        public_rating_id: row.public_rating_id,
        transaction_kind: 'commerce',
        score: row.score,
        review: row.review,
        status: row.rating_status,
        created_at: row.rating_created_at,
      }),
    })),
  });
}

async function suggestionsView(sql: DbClient, userId: string): Promise<Response> {
  const rows = await sql`
    SELECT public_suggestion_id, category, title, body, status,
           staff_response, public_attribution_consent, created_at, updated_at
    FROM public.hdc_suggestions
    WHERE member_id = ${userId}::uuid
    ORDER BY created_at DESC
    LIMIT 100
  `;
  return json({ suggestions: rows.map((row) => ({
    publicSuggestionId: String(row.public_suggestion_id),
    category: String(row.category),
    title: String(row.title),
    body: String(row.body),
    status: String(row.status),
    staffResponse: String(row.staff_response ?? ''),
    publicAttributionConsent: Boolean(row.public_attribution_consent),
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
  })) });
}

async function badgesView(sql: DbClient, userId: string): Promise<Response> {
  await sql`SELECT public.hdc_sync_member_badges(${userId}::uuid)`;
  const rows = await sql`
    SELECT badge.badge_key, definition.name, definition.description,
           definition.icon_key, definition.category, badge.evidence_count,
           badge.earned_at, badge.visible
    FROM public.hdc_member_badges badge
    JOIN public.hdc_badge_definitions definition USING (badge_key)
    WHERE badge.member_id = ${userId}::uuid
      AND badge.revoked_at IS NULL
      AND definition.active = true
    ORDER BY badge.earned_at DESC, definition.name
  `;
  return json({ badges: rows.map((row) => ({
    key: String(row.badge_key),
    name: String(row.name),
    description: String(row.description),
    iconKey: String(row.icon_key),
    category: String(row.category),
    evidenceCount: Number(row.evidence_count),
    earnedAt: String(row.earned_at),
    visible: Boolean(row.visible),
  })) });
}

async function submitRating(sql: DbClient, userId: string, body: Record<string, unknown>) {
  const kind = cleanText(body.transactionKind, 20).toLowerCase();
  const transactionId = cleanText(body.transactionId, 100);
  const score = Number(body.score);
  const review = cleanText(body.review, 1000);
  if (!['service', 'commerce'].includes(kind) || !transactionId ||
      !Number.isInteger(score) || score < 1 || score > 5) {
    return json({ error: 'invalid_rating' }, 400);
  }
  try {
    const rows = kind === 'service'
      ? await sql`
          INSERT INTO public.hdc_transaction_ratings(
            transaction_kind, service_transaction_id, rater_member_id,
            rated_member_id, score, review
          ) VALUES ('service', ${transactionId}, ${userId}::uuid, ${userId}::uuid, ${score}, ${review})
          RETURNING id, public_rating_id, transaction_kind, score, review, status, created_at
        `
      : await sql`
          INSERT INTO public.hdc_transaction_ratings(
            transaction_kind, purchase_request_id, rater_member_id,
            rated_member_id, score, review
          ) VALUES ('commerce', ${transactionId}::uuid, ${userId}::uuid, ${userId}::uuid, ${score}, ${review})
          RETURNING id, public_rating_id, transaction_kind, score, review, status, created_at
        `;
    return json({ rating: ratingView(rows[0]) }, 201);
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.includes('unique') || message.includes('duplicate')) {
      return json({ error: 'rating_already_submitted' }, 409);
    }
    if (message.includes('completed transaction') || message.includes('participant')) {
      return json({ error: 'rating_not_eligible' }, 409);
    }
    throw error;
  }
}

async function withdrawRating(sql: DbClient, userId: string, body: Record<string, unknown>) {
  const ratingId = cleanText(body.ratingId, 80);
  if (!ratingId) return json({ error: 'rating_required' }, 400);
  const rows = await sql`
    UPDATE public.hdc_transaction_ratings
    SET status = 'withdrawn', withdrawn_at = now()
    WHERE id = ${ratingId}::uuid
      AND rater_member_id = ${userId}::uuid
      AND status = 'active'
    RETURNING id
  `;
  if (rows.length === 0) return json({ error: 'rating_not_found' }, 404);
  return json({ withdrawn: true });
}

async function commerceProgress(sql: DbClient, userId: string, body: Record<string, unknown>, action: string) {
  const purchaseRequestId = cleanText(body.purchaseRequestId, 80);
  const version = Number(body.version);
  if (!purchaseRequestId || !Number.isInteger(version) || version < 1) {
    return json({ error: 'invalid_purchase_completion' }, 400);
  }
  const result = await sql.begin(async (tx) => {
    const current = await tx`
      SELECT id, buyer_user_id, seller_user_id, status, version
      FROM public.hdc_product_purchase_requests
      WHERE id = ${purchaseRequestId}::uuid
      FOR UPDATE
    `;
    if (current.length === 0) return { error: 'purchase_request_not_found', status: 404 } as const;
    const row = current[0];
    if (Number(row.version) !== version) return { error: 'purchase_request_conflict', status: 409 } as const;
    if (action === 'commerce_fulfill') {
      if (String(row.seller_user_id) !== userId || row.status !== 'accepted') {
        return { error: 'purchase_fulfillment_not_allowed', status: 409 } as const;
      }
      const updated = await tx`
        UPDATE public.hdc_product_purchase_requests
        SET status = 'fulfilled', fulfilled_at = now()
        WHERE id = ${purchaseRequestId}::uuid
        RETURNING id, version, status, fulfilled_at
      `;
      await tx`
        INSERT INTO public.hdc_product_purchase_request_events(
          purchase_request_id, actor_user_id, event_type, from_status, to_status, snapshot
        ) VALUES (${purchaseRequestId}::uuid, ${userId}::uuid, 'fulfilled', 'accepted', 'fulfilled', ${tx.json({ confirmation: 'seller_reported_fulfillment' })})
      `;
      return { purchase: updated[0] } as const;
    }
    if (String(row.buyer_user_id) !== userId || row.status !== 'fulfilled') {
      return { error: 'purchase_completion_not_allowed', status: 409 } as const;
    }
    const updated = await tx`
      UPDATE public.hdc_product_purchase_requests
      SET status = 'completed', completed_at = now()
      WHERE id = ${purchaseRequestId}::uuid
      RETURNING id, version, status, completed_at
    `;
    await tx`
      INSERT INTO public.hdc_product_purchase_request_events(
        purchase_request_id, actor_user_id, event_type, from_status, to_status, snapshot
      ) VALUES (${purchaseRequestId}::uuid, ${userId}::uuid, 'completed', 'fulfilled', 'completed', ${tx.json({ confirmation: 'buyer_confirmed_completion' })})
    `;
    await tx`SELECT public.hdc_sync_member_badges(${String(row.buyer_user_id)}::uuid)`;
    await tx`SELECT public.hdc_sync_member_badges(${String(row.seller_user_id)}::uuid)`;
    return { purchase: updated[0] } as const;
  });
  if ('error' in result) return json({ error: result.error }, result.status);
  return json({ purchase: {
    id: String(result.purchase.id),
    status: String(result.purchase.status),
    version: Number(result.purchase.version),
  }});
}

async function submitSuggestion(sql: DbClient, userId: string, body: Record<string, unknown>) {
  const category = cleanText(body.category, 40).toLowerCase();
  const title = cleanText(body.title, 160);
  const suggestionBody = cleanText(body.body, 5000);
  const consent = body.publicAttributionConsent === true;
  if (!suggestionCategories.has(category) || title.length < 4 || suggestionBody.length < 10) {
    return json({ error: 'invalid_suggestion' }, 400);
  }
  const rows = await sql`
    INSERT INTO public.hdc_suggestions(
      member_id, category, title, body, public_attribution_consent
    ) VALUES (${userId}::uuid, ${category}, ${title}, ${suggestionBody}, ${consent})
    RETURNING public_suggestion_id, category, title, status, created_at
  `;
  return json({ suggestion: {
    publicSuggestionId: String(rows[0].public_suggestion_id),
    category: String(rows[0].category),
    title: String(rows[0].title),
    status: String(rows[0].status),
    createdAt: String(rows[0].created_at),
  }}, 201);
}

async function setBadgeVisibility(sql: DbClient, userId: string, body: Record<string, unknown>) {
  const badgeKey = cleanText(body.badgeKey, 64);
  if (!badgeKey || typeof body.visible !== 'boolean') {
    return json({ error: 'invalid_badge_visibility' }, 400);
  }
  const rows = await sql`
    UPDATE public.hdc_member_badges
    SET visible = ${body.visible}
    WHERE member_id = ${userId}::uuid AND badge_key = ${badgeKey} AND revoked_at IS NULL
    RETURNING badge_key, visible
  `;
  if (rows.length === 0) return json({ error: 'badge_not_found' }, 404);
  return json({ badgeKey: String(rows[0].badge_key), visible: Boolean(rows[0].visible) });
}

async function handle(req: Request): Promise<Response> {
  if (!['GET', 'POST'].includes(req.method)) return methodNotAllowed();
  const sql = openDb();
  try {
    const authorization = await authorizeMemberRequest(req, sql);
    if (authorization instanceof Response) return authorization;
    const userId = authorization.userId;
    if (req.method === 'GET') {
      const view = new URL(req.url).searchParams.get('view') ?? 'ratings';
      if (view === 'ratings') return await ratingsView(sql, userId);
      if (view === 'suggestions') return await suggestionsView(sql, userId);
      if (view === 'badges') return await badgesView(sql, userId);
      return json({ error: 'invalid_community_view' }, 400);
    }
    if (operationMode() !== 'normal') return json({ error: 'service_read_only' }, 503);
    const body = await readJson(req);
    if (!body) return json({ error: 'invalid_json' }, 400);
    const action = cleanText(body.action, 40).toLowerCase();
    if (action === 'submit_rating') return await submitRating(sql, userId, body);
    if (action === 'withdraw_rating') return await withdrawRating(sql, userId, body);
    if (action === 'commerce_fulfill' || action === 'commerce_complete') {
      return await commerceProgress(sql, userId, body, action);
    }
    if (action === 'submit_suggestion') return await submitSuggestion(sql, userId, body);
    if (action === 'set_badge_visibility') return await setBadgeVisibility(sql, userId, body);
    return json({ error: 'invalid_community_action' }, 400);
  } catch (error) {
    console.error('Community API failed', error instanceof Error ? error.message : 'unknown_error');
    return json({ error: 'community_unavailable' }, 500);
  } finally {
    await closeDb(sql);
  }
}

export default async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return corsPreflightResponse(req);
  return withCors(req, await handle(req));
};

export const config = { path: '/api/community' };
