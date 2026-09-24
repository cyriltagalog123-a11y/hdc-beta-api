import { createHash, randomUUID } from 'node:crypto';
import postgres from 'postgres';
import { beforeAll, afterAll, describe, it, expect } from 'vitest';
import { handleHdcApiRequest } from '../netlify/functions/api.mjs';
import community from '../netlify/functions/community.mjs';
import { parseProductCatalogQuery } from '../netlify/functions/_lib/commerce.mjs';

type Account = { id: string; token: string };
type Row = Record<string, unknown>;
let sql: ReturnType<typeof postgres>;
let seller: Account;
let buyer: Account;
let other: Account;

async function call(path: string, account?: Account, body?: Row, method = body ? 'POST' : 'GET') {
  const request = new Request(`https://hdc-stability.test${path}`, {
    method, headers: { 'content-type': 'application/json',
      ...(account ? { authorization: `Bearer ${account.token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const response = path === '/api/community' ? await community(request) : await handleHdcApiRequest(request);
  return { status: response.status, body: await response.json() as Row };
}

async function account(label: string, selling = false): Promise<Account> {
  const email = `stability-${randomUUID()}@example.invalid`;
  const password = 'Build27!Stability-Isolated-5948';
  const registered = await call('/api/auth/register', undefined, {
    email, password, displayName: `Stability ${label}`, location: 'Cebu City, Central Visayas, Philippines',
    recoveryAnswers: [
      { questionCode: 'first_meal', answer: `${label} warm rice` },
      { questionCode: 'childhood_nickname', answer: `${label} blue comet` },
      { questionCode: 'private_phrase', answer: `${label} safe harbor` },
    ], termsAccepted: true, privacyAcknowledged: true, termsVersion: 'beta-2026-09-06',
  });
  expect(registered.status, JSON.stringify(registered.body)).toBe(201);
  const id = String((registered.body.user as Row).id);
  if (selling) await sql`
    INSERT INTO public.hdc_user_roles(user_id, role, is_active, status)
    VALUES (${id}::uuid, 'seller', true, 'active')
    ON CONFLICT(user_id, role) DO UPDATE SET is_active = true, status = 'active'
  `;
  const login = await call('/api/auth/login', undefined, { email, password });
  expect(login.status).toBe(200);
  return { id, token: String(login.body.token) };
}

const listingBody = {
  sellerRole: 'seller', categoryCode: 'laptops', title: 'Stability test laptop',
  description: 'A technology listing used only on the isolated integration database.',
  condition: 'used', currency: 'USD', unitPriceMinor: 19999, stockQuantity: 2, status: 'active',
};

async function listing(stock = 2) {
  const result = await call('/api/commerce/listings', seller, { ...listingBody, stockQuantity: stock });
  expect(result.status, JSON.stringify(result.body)).toBe(201);
  return result.body.listing as Row;
}
async function purchase(item: Row, actor = buyer, key = randomUUID(), quantity = 1) {
  return call('/api/commerce/purchase-requests', actor, {
    listingId: item.id, quantity, buyerNote: 'Recorded test note', clientRequestId: key,
    fulfillmentMethod: 'pickup', fulfillmentLocation: 'Cebu City public square',
    fulfillmentTiming: 'Saturday afternoon', fulfillmentFeeMinor: 350,
  });
}
async function decision(order: Row, action: string, actor = seller) {
  return call(`/api/commerce/purchase-requests/${order.id}/status`, actor,
    { action, version: order.version, note: '' }, 'PUT');
}
async function cancellation(order: Row, action: string, actor = buyer,
  note = action === 'request' ? 'I need to cancel this order.' : '') {
  return call(`/api/commerce/purchase-requests/${order.id}/cancellation`, actor,
    { action, version: order.version, note }, 'PUT');
}

describe.skipIf(process.env.HDC_POSTGRES_INTEGRATION !== '1').sequential('Build 27 commerce stability', () => {
  beforeAll(async () => {
    sql = postgres(process.env.HDC_DATABASE_URL!, { max: 4, prepare: false });
    seller = await account('Seller', true);
    buyer = await account('Buyer');
    other = await account('Other buyer');
  }, 60000);
  afterAll(async () => { await sql?.end({ timeout: 2 }); });

  it('hides inactive sellers and refuses requests while preserving the public field boundary', async () => {
    const item = await listing();
    const catalog = await call('/api/commerce/catalog');
    const visible = (catalog.body.listings as Row[]).find((row) => row.id === item.id)!;
    expect(visible).toBeDefined();
    expect(visible).not.toHaveProperty('sellerUserId');
    expect(visible).not.toHaveProperty('sellerProfileId');
    expect(visible).not.toHaveProperty('email');
    const detail = await call(`/api/commerce/catalog/${item.id}`);
    expect(detail.status).toBe(200);
    expect((detail.body.listing as Row).id).toBe(item.id);
    await sql`UPDATE public.hdc_users SET status = 'disabled' WHERE id = ${seller.id}::uuid`;
    try {
      const hidden = await call('/api/commerce/catalog');
      expect((hidden.body.listings as Row[]).some((row) => row.id === item.id)).toBe(false);
      expect((await call(`/api/commerce/catalog/${item.id}`)).status).toBe(404);
      expect((await purchase(item)).status).toBe(409);
    } finally { await sql`UPDATE public.hdc_users SET status = 'active' WHERE id = ${seller.id}::uuid`; }
  });

  it('links only an opted-in active seller profile and exposes its public fields', async () => {
    const item = await listing();
    const profileId = String(item.sellerProfileId);
    const profilePath = `/api/commerce/sellers/${profileId}`;
    const before = await call('/api/commerce/catalog');
    expect((before.body.listings as Row[]).find((row) => row.id === item.id)?.sellerPublicProfileId).toBeNull();
    expect((await call(profilePath)).status).toBe(404);
    await sql`UPDATE public.hdc_platform_role_profiles SET is_public = true
      WHERE id = ${profileId}::uuid`;
    try {
      const after = await call('/api/commerce/catalog');
      expect((after.body.listings as Row[]).find((row) => row.id === item.id)?.sellerPublicProfileId).toBe(profileId);
      const publicProfile = await call(profilePath);
      expect(publicProfile.status).toBe(200);
      expect(publicProfile.body.profile).toMatchObject({ id: profileId, role: 'seller' });
      for (const field of ['userId', 'contactEmail', 'contactPhone', 'details']) {
        expect(publicProfile.body.profile).not.toHaveProperty(field);
      }
    } finally {
      await sql`UPDATE public.hdc_platform_role_profiles SET is_public = false
        WHERE id = ${profileId}::uuid`;
    }
    expect((await call(profilePath)).status).toBe(404);
  });

  it('pages active listings by an exact published time and stable id', async () => {
    const older = await listing();
    const newer = await listing();
    const latest = await sql`
      SELECT to_char(published_at AT TIME ZONE 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS cursor_at
      FROM public.hdc_product_listings WHERE id = ${String(newer.id)}::uuid
    `;
    const cursor = Buffer.from(JSON.stringify({
      at: String(latest[0].cursor_at), id: String(newer.id),
      price: Number(newer.unitPriceMinor),
      filter: createHash('sha256').update(JSON.stringify(
        parseProductCatalogQuery(new URLSearchParams()),
      )).digest('hex').slice(0, 32),
    })).toString('base64url');
    const page = await call(`/api/commerce/catalog?cursor=${cursor}`);
    expect(page.status).toBe(200);
    expect((page.body.listings as Row[]).some((row) => row.id === older.id)).toBe(true);
    expect((page.body.listings as Row[]).some((row) => row.id === newer.id)).toBe(false);
  });

  it('serializes repeated requests and rejects an idempotency key with changed terms', async () => {
    const item = await listing();
    const key = randomUUID();
    const results = await Promise.all([purchase(item, buyer, key), purchase(item, buyer, key)]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 201]);
    expect((results[0].body.purchaseRequest as Row).id).toBe((results[1].body.purchaseRequest as Row).id);
    const changed = await purchase(item, buyer, key, 2);
    expect(changed.status).toBe(409);
    expect(changed.body.error).toBe('purchase_request_key_reused');
    const changedFee = await call('/api/commerce/purchase-requests', buyer, {
      listingId: item.id, quantity: 1, buyerNote: 'Recorded test note', clientRequestId: key,
      fulfillmentMethod: 'pickup', fulfillmentLocation: 'Cebu City public square',
      fulfillmentTiming: 'Saturday afternoon', fulfillmentFeeMinor: 351,
    });
    expect(changedFee.status).toBe(409);
    const counts = await sql`SELECT count(*)::int AS count FROM public.hdc_product_purchase_requests
      WHERE buyer_user_id = ${buyer.id}::uuid AND idempotency_key = ${key}::uuid`;
    expect(counts[0].count).toBe(1);
  });

  it('allocates the final item once for competing buyers and records the losing request', async () => {
    const item = await listing(1);
    const first = (await purchase(item)).body.purchaseRequest as Row;
    const second = (await purchase(item, other)).body.purchaseRequest as Row;
    const results = await Promise.all([decision(first, 'accept'), decision(second, 'accept')]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 409]);
    const stock = await sql`SELECT stock_quantity, status FROM public.hdc_product_listings WHERE id = ${String(item.id)}::uuid`;
    expect(stock[0]).toMatchObject({ stock_quantity: 0, status: 'sold' });
    const events = await sql`SELECT event.event_type, count(*)::int AS count
      FROM public.hdc_product_purchase_request_events event
      JOIN public.hdc_product_purchase_requests request ON request.id = event.purchase_request_id
      WHERE request.listing_id = ${String(item.id)}::uuid GROUP BY event.event_type`;
    expect(events.find((r) => r.event_type === 'accepted')?.count).toBe(1);
    expect(events.find((r) => r.event_type === 'declined')?.count).toBe(1);
    const stale = await call(`/api/commerce/listings/${item.id}`, seller, { ...listingBody, version: item.version }, 'PUT');
    expect(stale.status).toBe(409);
  });

  it('keeps monetary evidence unchanged and isolates decisions and buyer history', async () => {
    const item = await listing();
    const created = await purchase(item, buyer, randomUUID(), 2);
    const order = created.body.purchaseRequest as Row;
    expect(order).toMatchObject({ currency: 'USD', unitPriceMinor: 19999, subtotalMinor: 39998 });
    expect((await decision(order, 'accept', other)).status).toBe(404);
    expect((await decision(order, 'cancel', other)).status).toBe(404);
    const otherHistory = await call('/api/commerce/buyer-dashboard', other);
    expect((otherHistory.body.purchaseRequests as Row[]).some((row) => row.id === order.id)).toBe(false);
    const edited = await call(`/api/commerce/listings/${item.id}`, seller,
      { ...listingBody, currency: 'PHP', unitPriceMinor: 100, version: item.version }, 'PUT');
    expect(edited.status).toBe(200);
    const accepted = await decision(order, 'accept');
    expect(accepted.status).toBe(200);
    expect(accepted.body.purchaseRequest).toMatchObject({ currency: 'USD', unitPriceMinor: 19999, subtotalMinor: 39998 });
    await expect(sql`UPDATE public.hdc_product_purchase_requests SET unit_price_minor = 1
      WHERE id = ${String(order.id)}::uuid`).rejects.toThrow(/immutable/);
    await expect(sql`UPDATE public.hdc_product_purchase_requests SET fulfillment_fee_minor = 0
      WHERE id = ${String(order.id)}::uuid`).rejects.toThrow(/immutable/);
  });

  it('shows the same scoped purchase timeline to participants only', async () => {
    const item = await listing();
    const submitted = (await purchase(item)).body.purchaseRequest as Row;
    const accepted = await call(`/api/commerce/purchase-requests/${submitted.id}/status`, seller,
      { action: 'accept', version: submitted.version, note: 'Meet at the agreed public pickup point.' }, 'PUT');
    expect(accepted.status).toBe(200);
    const buyerHistory = await call('/api/commerce/buyer-dashboard', buyer);
    const sellerHistory = await call('/api/commerce/seller-dashboard', seller);
    const unrelatedHistory = await call('/api/commerce/buyer-dashboard', other);
    const buyerOrder = (buyerHistory.body.purchaseRequests as Row[]).find((row) => row.id === submitted.id)!;
    const sellerOrder = (sellerHistory.body.purchaseRequests as Row[]).find((row) => row.id === submitted.id)!;
    expect(buyerOrder.fulfillment).toEqual(sellerOrder.fulfillment);
    expect(buyerOrder.fulfillment).toMatchObject({ method: 'pickup',
      location: 'Cebu City public square', feeMinor: 350, totalMinor: 20349 });
    expect(buyerOrder.events).toEqual(sellerOrder.events);
    expect((buyerOrder.events as Row[]).map((event) => event.type)).toEqual(['submitted', 'accepted']);
    expect((buyerOrder.events as Row[])[1].note).toBe('Meet at the agreed public pickup point.');
    expect(JSON.stringify(buyerOrder.events)).not.toContain(seller.id);
    expect((unrelatedHistory.body.purchaseRequests as Row[]).some((row) => row.id === submitted.id)).toBe(false);
    expect((await call('/api/commerce/catalog?cursor=bad')).status).toBe(400);
    expect((await call('/api/commerce/buyer-dashboard?cursor=bad', buyer)).status).toBe(400);
  });

  it('checks completion participants before version and denies revoked seller fulfillment', async () => {
    const item = await listing();
    const submitted = (await purchase(item)).body.purchaseRequest as Row;
    const accepted = (await decision(submitted, 'accept')).body.purchaseRequest as Row;
    const body = { action: 'commerce_fulfill', purchaseRequestId: accepted.id, version: accepted.version };
    for (const version of [1, accepted.version, 999]) {
      const denied = await call('/api/community', other, { ...body, version });
      expect(denied.status).toBe(404);
      expect(denied.body.error).toBe('purchase_request_not_found');
    }
    expect((await call('/api/community', seller, { ...body, purchaseRequestId: 'invalid' })).status).toBe(400);
    await sql`UPDATE public.hdc_user_roles SET is_active = false, status = 'revoked'
      WHERE user_id = ${seller.id}::uuid AND role = 'seller'`;
    try { expect((await call('/api/community', seller, body)).status).toBe(403); }
    finally { await sql`UPDATE public.hdc_user_roles SET is_active = true, status = 'active'
      WHERE user_id = ${seller.id}::uuid AND role = 'seller'`; }
    const fulfilled = await call('/api/community', seller, body);
    expect(fulfilled.status).toBe(200);
    const complete = { action: 'commerce_complete', purchaseRequestId: accepted.id,
      version: (fulfilled.body.purchase as Row).version };
    const completed = await call('/api/community', buyer, complete);
    expect(completed.status).toBe(200);
    expect((await call('/api/community', buyer, complete)).status).toBe(409);
    const counts = await sql`SELECT count(*)::int AS count FROM public.hdc_product_purchase_request_events
      WHERE purchase_request_id = ${String(accepted.id)}::uuid AND event_type = 'completed'`;
    expect(counts[0].count).toBe(1);
  });

  it('requires both participants and restores accepted stock exactly once', async () => {
    const item = await listing(1);
    const submitted = (await purchase(item)).body.purchaseRequest as Row;
    const accepted = (await decision(submitted, 'accept')).body.purchaseRequest as Row;
    expect((await cancellation(accepted, 'approve', other)).status).toBe(404);
    const requested = await cancellation(accepted, 'request', buyer);
    expect(requested.status).toBe(200);
    const pending = requested.body.purchaseRequest as Row;
    expect(pending).toMatchObject({ status: 'accepted', cancellationRequestedBy: 'buyer' });
    expect((await cancellation(pending, 'approve', buyer)).status).toBe(409);
    expect((await call('/api/community', seller, { action: 'commerce_fulfill',
      purchaseRequestId: accepted.id, version: pending.version })).status).toBe(409);
    const [first, second] = await Promise.all([
      cancellation(pending, 'approve', seller),
      cancellation(pending, 'approve', seller),
    ]);
    expect([first.status, second.status].sort()).toEqual([200, 409]);
    const completed = (first.status === 200 ? first : second).body.purchaseRequest as Row;
    expect(completed).toMatchObject({ status: 'cancelled', cancellationRequestedBy: 'buyer' });
    expect(completed.stockReleasedAt).toBeTruthy();
    expect((await cancellation(completed, 'approve', seller)).status).toBe(409);
    const stock = await sql`SELECT stock_quantity, status, sold_at
      FROM public.hdc_product_listings WHERE id = ${String(item.id)}::uuid`;
    expect(stock[0]).toMatchObject({ stock_quantity: 1, status: 'paused', sold_at: null });
    const buyerHistory = await call('/api/commerce/buyer-dashboard', buyer);
    const sellerHistory = await call('/api/commerce/seller-dashboard', seller);
    const buyerOrder = (buyerHistory.body.purchaseRequests as Row[]).find((row) => row.id === accepted.id)!;
    const sellerOrder = (sellerHistory.body.purchaseRequests as Row[]).find((row) => row.id === accepted.id)!;
    expect(buyerOrder.events).toEqual(sellerOrder.events);
    expect((buyerOrder.events as Row[]).map((event) => event.type)).toEqual([
      'submitted', 'accepted', 'cancellation_requested', 'cancelled',
    ]);
    expect((await call('/api/commerce/buyer-dashboard', other)).body.purchaseRequests)
      .not.toContainEqual(expect.objectContaining({ id: accepted.id }));
    await expect(sql`UPDATE public.hdc_product_purchase_requests
      SET stock_released_at = NULL WHERE id = ${String(accepted.id)}::uuid`)
      .rejects.toThrow(/cannot be released twice/);
  });

  it('allows a seller request and buyer decline without releasing stock', async () => {
    const item = await listing(2);
    const submitted = (await purchase(item)).body.purchaseRequest as Row;
    const accepted = (await decision(submitted, 'accept')).body.purchaseRequest as Row;
    const requested = (await cancellation(accepted, 'request', seller)).body.purchaseRequest as Row;
    expect(requested.cancellationRequestedBy).toBe('seller');
    const declined = await cancellation(requested, 'decline', buyer, 'I still want this item.');
    expect(declined.status).toBe(200);
    expect(declined.body.purchaseRequest).toMatchObject({ status: 'accepted',
      cancellationRequestedBy: null, stockReleasedAt: null });
    const stock = await sql`SELECT stock_quantity FROM public.hdc_product_listings
      WHERE id = ${String(item.id)}::uuid`;
    expect(stock[0].stock_quantity).toBe(1);
    const fulfilled = await call('/api/community', seller, { action: 'commerce_fulfill',
      purchaseRequestId: accepted.id, version: (declined.body.purchaseRequest as Row).version });
    expect(fulfilled.status).toBe(200);
    expect((await cancellation(fulfilled.body.purchase as Row, 'request', buyer)).status).toBe(409);
  });

  it('searches the complete catalog and pages price sorts without mixing filters', async () => {
    const item = await call('/api/commerce/listings', seller, {
      ...listingBody, currency: 'ZAR', title: 'Build 29 catalog needle',
      unitPriceMinor: 5000,
    });
    expect(item.status).toBe(201);
    const target = item.body.listing as Row;
    await sql`UPDATE public.hdc_product_listings SET published_at = now() - interval '2 days'
      WHERE id = ${String(target.id)}::uuid`;
    await sql`
      INSERT INTO public.hdc_product_listings (
        seller_profile_id, seller_user_id, seller_role, category_code, title,
        description, item_condition, currency, unit_price_minor, stock_quantity,
        status, published_at
      )
      SELECT ${String(target.sellerProfileId)}::uuid, ${seller.id}::uuid,
        'seller', 'laptops', 'Build 29 catalog filler ' || series.number,
        'A listed item for isolated catalog pagination testing.', 'new', 'ZAR',
        5000 + series.number, 2, 'active', now()
      FROM generate_series(1, 105) AS series(number)
    `;
    const unfiltered = await call('/api/commerce/catalog');
    expect((unfiltered.body.listings as Row[]).some((row) => row.id === target.id)).toBe(false);
    const found = await call('/api/commerce/catalog?q=Build%2029%20catalog%20needle');
    expect((found.body.listings as Row[]).map((row) => row.id)).toEqual([target.id]);
    expect((await call(`/api/commerce/catalog/${target.id}`)).status).toBe(200);
    expect(found.body.availableCurrencies).toContain('ZAR');
    const first = await call('/api/commerce/catalog?currency=ZAR&sort=priceLow');
    expect(first.status).toBe(200);
    expect((first.body.listings as Row[]).length).toBe(100);
    expect((first.body.listings as Row[])[0].id).toBe(target.id);
    const cursor = String(first.body.nextCursor);
    const next = await call(`/api/commerce/catalog?currency=ZAR&sort=priceLow&cursor=${cursor}`);
    expect(next.status).toBe(200);
    expect((next.body.listings as Row[]).length).toBe(6);
    expect(next.body.nextCursor).toBeNull();
    expect((await call(`/api/commerce/catalog?currency=ZAR&sort=priceHigh&cursor=${cursor}`)).status).toBe(400);
    expect((await call('/api/commerce/catalog?sort=priceLow')).status).toBe(400);
  });
});
