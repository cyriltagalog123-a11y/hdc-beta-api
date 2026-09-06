import postgres from 'postgres';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { handleHdcApiRequest } from '../netlify/functions/api.mjs';
import communityHandler from '../netlify/functions/community.mjs';
import communityAdminHandler from '../netlify/functions/community-admin.mjs';

const runPostgresIntegration = process.env.HDC_POSTGRES_INTEGRATION === '1';

type TestAccount = {
  id: string;
  email: string;
  password: string;
  token: string;
};

type ApiResult = {
  response: Response;
  body: Record<string, unknown>;
};

let sql: ReturnType<typeof postgres> | null = null;
let customer: TestAccount;
let technician: TestAccount;
let buyer: TestAccount;
let seller: TestAccount;
let outsider: TestAccount;
let admin: TestAccount;
let owner: TestAccount;
let sequence = 0;

function nextRef(prefix: string): string {
  sequence += 1;
  return `${prefix}-${Date.now()}-${sequence}`;
}

async function parse(response: Response): Promise<ApiResult> {
  return {
    response,
    body: await response.json() as Record<string, unknown>,
  };
}

async function mainApi(path: string, init: RequestInit = {}, token?: string) {
  return parse(await handleHdcApiRequest(new Request(`https://hdc-community.test${path}`, {
    ...init,
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(init.headers ?? {}),
    },
  })));
}

async function communityApi(path: string, init: RequestInit = {}, token?: string) {
  return parse(await communityHandler(new Request(`https://hdc-community.test${path}`, {
    ...init,
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(init.headers ?? {}),
    },
  })));
}

async function adminApi(path: string, init: RequestInit = {}, token?: string) {
  return parse(await communityAdminHandler(new Request(`https://hdc-community.test${path}`, {
    ...init,
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(init.headers ?? {}),
    },
  })));
}

function expectStatus(result: ApiResult, status: number): void {
  expect(result.response.status, JSON.stringify(result.body)).toBe(status);
}

async function register(label: string): Promise<Omit<TestAccount, 'token'>> {
  const slug = label.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  const email = `${slug}-${nextRef('acct').toLowerCase()}@example.invalid`;
  const password = 'Build26!Community-Test-4829';
  const result = await mainApi('/api/auth/register', {
    method: 'POST',
    body: JSON.stringify({
      email,
      password,
      displayName: `HDC ${label}`,
      location: 'Cebu City, Central Visayas, Philippines',
      recoveryAnswers: [
        { questionCode: 'first_meal', answer: `${label} warm rice` },
        { questionCode: 'childhood_nickname', answer: `${label} blue comet` },
        { questionCode: 'private_phrase', answer: `${label} safe harbor` },
      ],
      termsAccepted: true,
      privacyAcknowledged: true,
      termsVersion: 'beta-2026-09-06',
    }),
  });
  expectStatus(result, 201);
  return {
    id: String((result.body.user as Record<string, unknown>).id),
    email,
    password,
  };
}

async function login(account: Omit<TestAccount, 'token'>): Promise<TestAccount> {
  const result = await mainApi('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email: account.email, password: account.password }),
  });
  expectStatus(result, 200);
  return { ...account, token: String(result.body.token) };
}

async function createCompletedService(): Promise<string> {
  const requestId = nextRef('SR-COMMUNITY');
  const created = await mainApi('/api/service-requests', {
    method: 'POST',
    body: JSON.stringify({
      id: requestId,
      title: 'Community rating regression service',
      categoryId: 'laptop-repair',
      categoryName: 'Laptop Repair',
      description: 'A completed service created to verify transaction-bound rating rules.',
      location: 'Cebu City, Central Visayas, Philippines',
      preferredDate: '2030-09-05T09:00:00.000Z',
      preferredTime: 'Morning',
      urgency: 'normal',
      minimumBudget: 500,
      maximumBudget: 3000,
      status: 'open',
    }),
  }, customer.token);
  expectStatus(created, 201);

  const proposalId = nextRef('PR-COMMUNITY');
  const proposed = await mainApi('/api/proposals', {
    method: 'POST',
    body: JSON.stringify({
      id: proposalId,
      requestId,
      status: 'submitted',
      serviceFee: 1200,
      partsArrangement: 'technicianSupplies',
      estimatedPartsCost: 350,
      earliestArrival: '2030-09-05T10:00:00.000Z',
      estimatedDurationMinutes: 120,
      warrantyType: 'thirtyDays',
      customWarrantyDays: null,
      diagnosis: 'Test diagnosis with enough detail for the proposal validation rules.',
      repairApproach: 'Inspect, verify the fault, and complete only the approved repair scope.',
      professionalNotes: 'Community regression transaction.',
      attachmentIds: [],
      submittedAt: null,
      viewedAt: null,
      shortlistedAt: null,
      declinedAt: null,
      withdrawnAt: null,
    }),
  }, technician.token);
  expectStatus(proposed, 201);

  const accepted = await mainApi(`/api/proposals/${proposalId}/accept`, {
    method: 'POST',
  }, customer.token);
  expectStatus(accepted, 200);
  const transactionId = String(
    (accepted.body.serviceTransaction as Record<string, unknown>).id,
  );

  await sql!`
    UPDATE public.hdc_service_transactions
    SET status = 'completed'
    WHERE id = ${transactionId}
  `;
  return transactionId;
}

async function createAcceptedCommercePurchase(): Promise<string> {
  const profile = await sql!`
    SELECT id, public_name
    FROM public.hdc_platform_role_profiles
    WHERE user_id = ${seller.id}::uuid AND role = 'seller'
    LIMIT 1
  `;
  expect(profile.length).toBe(1);

  const buyerRow = await sql!`
    SELECT display_name, public_member_id
    FROM public.hdc_users
    WHERE id = ${buyer.id}::uuid
  `;
  const listing = await sql!`
    INSERT INTO public.hdc_product_listings(
      seller_profile_id, seller_user_id, seller_role, category_code,
      title, description, item_condition, currency, unit_price_minor,
      stock_quantity, status, published_at
    ) VALUES (
      ${String(profile[0].id)}::uuid, ${seller.id}::uuid, 'seller', 'laptops',
      'Build 26 rating test laptop',
      'A valid technology listing used only for the Build 26 community regression suite.',
      'used', 'PHP', 2500000, 1, 'active', now()
    )
    RETURNING id, public_listing_id
  `;

  const purchase = await sql!`
    INSERT INTO public.hdc_product_purchase_requests(
      idempotency_key, listing_id, seller_user_id, seller_role, buyer_user_id,
      public_listing_id_snapshot, listing_title_snapshot, seller_name_snapshot,
      buyer_name_snapshot, buyer_public_member_id_snapshot, quantity, currency,
      unit_price_minor, subtotal_minor, buyer_note, seller_note, status, decided_at
    ) VALUES (
      gen_random_uuid(), ${String(listing[0].id)}::uuid, ${seller.id}::uuid,
      'seller', ${buyer.id}::uuid, ${String(listing[0].public_listing_id)},
      'Build 26 rating test laptop', ${String(profile[0].public_name)},
      ${String(buyerRow[0].display_name)}, ${String(buyerRow[0].public_member_id)},
      1, 'PHP', 2500000, 2500000, 'Buyer test note', 'Accepted for test',
      'accepted', now()
    )
    RETURNING id
  `;
  return String(purchase[0].id);
}

describe.skipIf(!runPostgresIntegration).sequential(
  'Build 26 ratings, suggestions, and badges',
  () => {
    beforeAll(async () => {
      const databaseUrl = process.env.HDC_DATABASE_URL;
      if (!databaseUrl) throw new Error('HDC_DATABASE_URL is required.');
      sql = postgres(databaseUrl, { max: 4, prepare: false });

      const rawCustomer = await register('Rating Customer');
      const rawTechnician = await register('Rating Technician');
      const rawBuyer = await register('Marketplace Buyer');
      const rawSeller = await register('Marketplace Seller');
      const rawOutsider = await register('Rating Outsider');
      const rawAdmin = await register('Suggestion Admin');
      const rawOwner = await register('Suggestion Owner');

      await sql`
        INSERT INTO public.hdc_user_roles(user_id, role, is_active)
        VALUES
          (${rawTechnician.id}::uuid, 'technician', true),
          (${rawSeller.id}::uuid, 'seller', true)
        ON CONFLICT(user_id, role) DO UPDATE
        SET is_active = true, status = 'active'
      `;
      await sql`
        INSERT INTO public.hdc_internal_role_assignments(
          user_id, role, is_active, assignment_note
        ) VALUES
          (${rawAdmin.id}::uuid, 'admin', true, 'Build 26 admin denial regression'),
          (${rawOwner.id}::uuid, 'owner', true, 'Build 26 owner suggestion regression')
        ON CONFLICT(user_id, role) DO UPDATE SET is_active = true
      `;

      customer = await login(rawCustomer);
      technician = await login(rawTechnician);
      buyer = await login(rawBuyer);
      seller = await login(rawSeller);
      outsider = await login(rawOutsider);
      admin = await login(rawAdmin);
      owner = await login(rawOwner);
    }, 90_000);

    afterAll(async () => {
      await sql?.end({ timeout: 2 });
      sql = null;
    });

    it('allows ratings only after a completed service and derives the real counterparty', async () => {
      const transactionId = await createCompletedService();

      const rejectedOutsider = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'submit_rating',
          transactionKind: 'service',
          transactionId,
          score: 1,
          review: 'Outsider should never be able to rate this transaction.',
        }),
      }, outsider.token);
      expectStatus(rejectedOutsider, 409);
      expect(rejectedOutsider.body.error).toBe('rating_not_eligible');

      const customerRating = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'submit_rating',
          transactionKind: 'service',
          transactionId,
          score: 5,
          review: 'Completed service rating from the actual customer.',
        }),
      }, customer.token);
      expectStatus(customerRating, 201);

      const persisted = await sql!`
        SELECT rater_member_id, rated_member_id, score
        FROM public.hdc_transaction_ratings
        WHERE service_transaction_id = ${transactionId}
          AND rater_member_id = ${customer.id}::uuid
      `;
      expect(String(persisted[0].rated_member_id)).toBe(technician.id);
      expect(Number(persisted[0].score)).toBe(5);

      const duplicate = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'submit_rating', transactionKind: 'service', transactionId,
          score: 4, review: 'Duplicate rating must be rejected.',
        }),
      }, customer.token);
      expectStatus(duplicate, 409);
      expect(duplicate.body.error).toBe('rating_already_submitted');

      const reciprocal = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'submit_rating', transactionKind: 'service', transactionId,
          score: 5, review: 'Technician can also rate the actual customer.',
        }),
      }, technician.token);
      expectStatus(reciprocal, 201);
    });

    it('rejects service ratings before completion and preserves withdrawn rating history', async () => {
      const requestId = nextRef('SR-INCOMPLETE');
      const created = await mainApi('/api/service-requests', {
        method: 'POST',
        body: JSON.stringify({
          id: requestId,
          title: 'Incomplete service cannot be rated',
          categoryId: 'laptop-repair',
          categoryName: 'Laptop Repair',
          description: 'This transaction remains active so the rating endpoint must stay locked.',
          location: 'Cebu City, Central Visayas, Philippines',
          preferredDate: '2030-09-06T09:00:00.000Z',
          preferredTime: 'Morning',
          urgency: 'normal', minimumBudget: 500, maximumBudget: 3000,
          status: 'open',
        }),
      }, customer.token);
      expectStatus(created, 201);
      const proposalId = nextRef('PR-INCOMPLETE');
      const proposal = await mainApi('/api/proposals', {
        method: 'POST',
        body: JSON.stringify({
          id: proposalId, requestId, status: 'submitted', serviceFee: 900,
          partsArrangement: 'none', estimatedPartsCost: null,
          earliestArrival: '2030-09-06T10:00:00.000Z', estimatedDurationMinutes: 60,
          warrantyType: 'sevenDays', customWarrantyDays: null,
          diagnosis: 'Enough detail for incomplete rating eligibility test.',
          repairApproach: 'Inspect and diagnose without closing the transaction.',
          professionalNotes: '', attachmentIds: [], submittedAt: null,
          viewedAt: null, shortlistedAt: null, declinedAt: null, withdrawnAt: null,
        }),
      }, technician.token);
      expectStatus(proposal, 201);
      const accepted = await mainApi(`/api/proposals/${proposalId}/accept`, {
        method: 'POST',
      }, customer.token);
      expectStatus(accepted, 200);
      const transactionId = String(
        (accepted.body.serviceTransaction as Record<string, unknown>).id,
      );

      const tooEarly = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'submit_rating', transactionKind: 'service', transactionId,
          score: 5, review: 'This must stay rejected while the service is active.',
        }),
      }, customer.token);
      expectStatus(tooEarly, 409);
      expect(tooEarly.body.error).toBe('rating_not_eligible');

      await sql!`UPDATE public.hdc_service_transactions SET status = 'completed' WHERE id = ${transactionId}`;
      const rating = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'submit_rating', transactionKind: 'service', transactionId,
          score: 4, review: 'A valid rating that will be withdrawn for history testing.',
        }),
      }, customer.token);
      expectStatus(rating, 201);
      const ratingId = String((rating.body.rating as Record<string, unknown>).id);

      const withdrawn = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({ action: 'withdraw_rating', ratingId }),
      }, customer.token);
      expectStatus(withdrawn, 200);

      await expect(sql!`
        DELETE FROM public.hdc_transaction_ratings WHERE id = ${ratingId}::uuid
      `).rejects.toThrow(/retained|withdraw/i);
      const retained = await sql!`
        SELECT status, withdrawn_at IS NOT NULL AS has_withdrawn_at
        FROM public.hdc_transaction_ratings WHERE id = ${ratingId}::uuid
      `;
      expect(retained[0].status).toBe('withdrawn');
      expect(retained[0].has_withdrawn_at).toBe(true);
    });

    it('requires seller fulfillment then buyer confirmation before marketplace ratings unlock', async () => {
      const purchaseRequestId = await createAcceptedCommercePurchase();

      const buyerCannotFulfill = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'commerce_fulfill', purchaseRequestId, version: 1,
        }),
      }, buyer.token);
      expectStatus(buyerCannotFulfill, 409);

      const sellerFulfilled = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'commerce_fulfill', purchaseRequestId, version: 1,
        }),
      }, seller.token);
      expectStatus(sellerFulfilled, 200);
      const fulfilledVersion = Number(
        (sellerFulfilled.body.purchase as Record<string, unknown>).version,
      );
      expect(fulfilledVersion).toBeGreaterThan(1);

      const sellerCannotComplete = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'commerce_complete', purchaseRequestId, version: fulfilledVersion,
        }),
      }, seller.token);
      expectStatus(sellerCannotComplete, 409);

      const buyerCompleted = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'commerce_complete', purchaseRequestId, version: fulfilledVersion,
        }),
      }, buyer.token);
      expectStatus(buyerCompleted, 200);

      const purchase = await sql!`
        SELECT status, fulfilled_at IS NOT NULL AS fulfilled,
               completed_at IS NOT NULL AS completed
        FROM public.hdc_product_purchase_requests
        WHERE id = ${purchaseRequestId}::uuid
      `;
      expect(purchase[0].status).toBe('completed');
      expect(purchase[0].fulfilled).toBe(true);
      expect(purchase[0].completed).toBe(true);

      const buyerRating = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'submit_rating', transactionKind: 'commerce',
          transactionId: purchaseRequestId, score: 5,
          review: 'Buyer rates seller only after confirmed completion.',
        }),
      }, buyer.token);
      expectStatus(buyerRating, 201);

      const sellerRating = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'submit_rating', transactionKind: 'commerce',
          transactionId: purchaseRequestId, score: 5,
          review: 'Seller can reciprocally rate the real buyer.',
        }),
      }, seller.token);
      expectStatus(sellerRating, 201);

      const outsiderRating = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'submit_rating', transactionKind: 'commerce',
          transactionId: purchaseRequestId, score: 1, review: 'Outsider abuse.',
        }),
      }, outsider.token);
      expectStatus(outsiderRating, 409);

      const buyerBadges = await communityApi('/api/community?view=badges', {}, buyer.token);
      expectStatus(buyerBadges, 200);
      const buyerBadgeKeys = (buyerBadges.body.badges as Record<string, unknown>[])
        .map((badge) => String(badge.key));
      expect(buyerBadgeKeys).toContain('first_marketplace_complete');

      const sellerBadges = await communityApi('/api/community?view=badges', {}, seller.token);
      expectStatus(sellerBadges, 200);
      const sellerBadgeKeys = (sellerBadges.body.badges as Record<string, unknown>[])
        .map((badge) => String(badge.key));
      expect(sellerBadgeKeys).toContain('first_marketplace_complete');
    });

    it('tracks suggestions, restricts full management to Owner, and awards Helpful Contributor only after implementation', async () => {
      const submitted = await communityApi('/api/community', {
        method: 'POST',
        body: JSON.stringify({
          action: 'submit_suggestion',
          category: 'usability',
          title: 'Make completed transaction feedback easier to find',
          body: 'Show a clear feedback entry point after a recorded transaction reaches the completed state.',
          publicAttributionConsent: true,
        }),
      }, customer.token);
      expectStatus(submitted, 201);
      const publicSuggestionId = String(
        (submitted.body.suggestion as Record<string, unknown>).publicSuggestionId,
      );

      const denied = await adminApi('/api/internal/community', {}, outsider.token);
      expect([403, 404]).toContain(denied.response.status);

      const deniedAdmin = await adminApi('/api/internal/community', {}, admin.token);
      expectStatus(deniedAdmin, 403);
      expect(deniedAdmin.body.error).toBe('suggestion_management_forbidden');

      const queue = await adminApi('/api/internal/community', {}, owner.token);
      expectStatus(queue, 200);
      const suggestion = (queue.body.suggestions as Record<string, unknown>[])
        .find((item) => String(item.publicSuggestionId) === publicSuggestionId);
      expect(suggestion).toBeDefined();
      expect(suggestion?.publicAttributionConsent).toBe(true);

      const before = await communityApi('/api/community?view=badges', {}, customer.token);
      expectStatus(before, 200);
      expect((before.body.badges as Record<string, unknown>[])
        .map((badge) => String(badge.key)))
        .not.toContain('helpful_contributor');

      const implemented = await adminApi('/api/internal/community', {
        method: 'PUT',
        body: JSON.stringify({
          id: suggestion?.id,
          status: 'implemented',
          staffResponse: 'Implemented and verified in the Build 26 community workflow.',
        }),
      }, owner.token);
      expectStatus(implemented, 200);
      expect((implemented.body.suggestion as Record<string, unknown>).status)
        .toBe('implemented');

      const after = await communityApi('/api/community?view=badges', {}, customer.token);
      expectStatus(after, 200);
      const contributor = (after.body.badges as Record<string, unknown>[])
        .find((badge) => String(badge.key) === 'helpful_contributor');
      expect(contributor).toBeDefined();
      expect(Number(contributor?.evidenceCount)).toBeGreaterThanOrEqual(1);
    });
  },
);
