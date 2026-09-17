import { randomUUID } from 'node:crypto';
import postgres from 'postgres';
import { beforeAll, afterAll, describe, it, expect } from 'vitest';
import { handleHdcApiRequest } from '../netlify/functions/api.mjs';
import community from '../netlify/functions/community.mjs';

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
  });
}
async function decision(order: Row, action: string, actor = seller) {
  return call(`/api/commerce/purchase-requests/${order.id}/status`, actor,
    { action, version: order.version, note: '' }, 'PUT');
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
    await sql`UPDATE public.hdc_users SET status = 'disabled' WHERE id = ${seller.id}::uuid`;
    try {
      const hidden = await call('/api/commerce/catalog');
      expect((hidden.body.listings as Row[]).some((row) => row.id === item.id)).toBe(false);
      expect((await purchase(item)).status).toBe(409);
    } finally { await sql`UPDATE public.hdc_users SET status = 'active' WHERE id = ${seller.id}::uuid`; }
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
});
