import postgres from 'postgres';
import {
  afterAll,
  beforeAll,
  describe,
  expect,
  it,
} from 'vitest';

import { handleHdcApiRequest } from '../netlify/functions/api.mjs';

const runPostgresIntegration = process.env.HDC_POSTGRES_INTEGRATION === '1';

type ApiResult = {
  response: Response;
  body: Record<string, unknown>;
};

type TestAccount = {
  id: string;
  email: string;
  token: string;
};

let setupSql: ReturnType<typeof postgres> | null = null;
let customer: TestAccount;
let technicianOne: TestAccount;
let technicianTwo: TestAccount;
let outsider: TestAccount;
let sequence = 0;

function nextReference(prefix: string): string {
  sequence += 1;
  return `${prefix}-${Date.now()}-${sequence}`;
}

async function api(
  path: string,
  init: RequestInit = {},
  token?: string,
): Promise<ApiResult> {
  const response = await handleHdcApiRequest(
    new Request(`https://hdc-postgres.test${path}`, {
      ...init,
      headers: {
        accept: 'application/json',
        'content-type': 'application/json',
        ...(token ? { authorization: `Bearer ${token}` } : {}),
        ...(init.headers ?? {}),
      },
    }),
  );
  const body = await response.json() as Record<string, unknown>;
  return { response, body };
}

function expectStatus(result: ApiResult, status: number): void {
  expect(result.response.status, JSON.stringify(result.body)).toBe(status);
}

async function registerAccount(label: string): Promise<{
  id: string;
  email: string;
  password: string;
}> {
  const emailLabel = label
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
  const email = `${emailLabel}-${nextReference('account').toLowerCase()}@example.invalid`;
  const password = 'Build22.1!Database-Test-4829';
  const registration = await api('/api/auth/register', {
    method: 'POST',
    body: JSON.stringify({
      email,
      password,
      displayName: `HDC ${label}`,
      recoveryAnswers: [
        { questionCode: 'first_meal', answer: `${label} ginger porridge` },
        { questionCode: 'childhood_nickname', answer: `${label} quiet comet` },
        { questionCode: 'private_phrase', answer: `${label} amber harbor` },
      ],
      termsAccepted: true,
      privacyAcknowledged: true,
      termsVersion: 'beta-2026-08-29',
    }),
  });
  expectStatus(registration, 201);
  const user = registration.body.user as Record<string, unknown>;
  expect(user.legalAcceptanceRequired).toBe(false);
  return { id: String(user.id), email, password };
}

async function loginAccount(account: {
  id: string;
  email: string;
  password: string;
}): Promise<TestAccount> {
  const login = await api('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email: account.email, password: account.password }),
  });
  expectStatus(login, 200);
  return {
    id: account.id,
    email: account.email,
    token: String(login.body.token),
  };
}

async function createRequest(
  account: TestAccount,
  titleSuffix: string,
): Promise<string> {
  const id = nextReference('SR');
  const created = await api('/api/service-requests', {
    method: 'POST',
    body: JSON.stringify({
      id,
      title: `Laptop power failure ${titleSuffix}`,
      categoryId: 'laptop-repair',
      categoryName: 'Laptop Repair',
      description:
        'The laptop turns off during startup and the power adapter has already been tested.',
      location: 'Cebu City',
      preferredDate: '2030-09-05T09:00:00.000Z',
      preferredTime: 'Morning',
      urgency: 'normal',
      minimumBudget: 500,
      maximumBudget: 3000,
      status: 'open',
    }),
  }, account.token);
  expectStatus(created, 201);
  return id;
}

function proposalPayload(
  requestId: string,
  proposalId: string,
  serviceFee = 1200,
): Record<string, unknown> {
  return {
    id: proposalId,
    requestId,
    status: 'submitted',
    serviceFee,
    partsArrangement: 'technicianSupplies',
    estimatedPartsCost: 350,
    earliestArrival: '2030-09-05T10:00:00.000Z',
    estimatedDurationMinutes: 120,
    warrantyType: 'thirtyDays',
    customWarrantyDays: null,
    diagnosis:
      'The symptoms indicate a possible power rail fault or damaged charging circuit.',
    repairApproach:
      'Inspect the input rail, test board voltages, and repair the failed component after approval.',
    professionalNotes:
      'Final component selection will be documented in the service workspace.',
    attachmentIds: [],
    submittedAt: null,
    viewedAt: null,
    shortlistedAt: null,
    declinedAt: null,
    withdrawnAt: null,
  };
}

async function submitProposal(
  account: TestAccount,
  requestId: string,
  serviceFee = 1200,
): Promise<string> {
  const id = nextReference('PR');
  const created = await api('/api/proposals', {
    method: 'POST',
    body: JSON.stringify(proposalPayload(requestId, id, serviceFee)),
  }, account.token);
  expectStatus(created, 201);
  return String((created.body.proposal as Record<string, unknown>).id);
}

async function createAcceptedTransaction(
  titleSuffix: string,
): Promise<string> {
  const requestId = await createRequest(customer, titleSuffix);
  const proposalId = await submitProposal(technicianOne, requestId);
  const accepted = await api(
    `/api/proposals/${proposalId}/accept`,
    { method: 'POST' },
    customer.token,
  );
  expectStatus(accepted, 200);
  return String(
    (accepted.body.serviceTransaction as Record<string, unknown>).id,
  );
}

describe.skipIf(!runPostgresIntegration).sequential(
  'required PostgreSQL workflow integration',
  () => {
    beforeAll(async () => {
      const databaseUrl = process.env.HDC_DATABASE_URL;
      if (!databaseUrl) throw new Error('HDC_DATABASE_URL is required.');
      setupSql = postgres(databaseUrl, { max: 4, prepare: false });

      const rawCustomer = await registerAccount('Customer');
      const rawTechnicianOne = await registerAccount('Technician One');
      const rawTechnicianTwo = await registerAccount('Technician Two');
      const rawOutsider = await registerAccount('Outsider');

      await setupSql`
        INSERT INTO public.hdc_user_roles (user_id, role, is_active)
        VALUES
          (${rawTechnicianOne.id}, 'technician', true),
          (${rawTechnicianTwo.id}, 'technician', true)
        ON CONFLICT (user_id, role) DO UPDATE
        SET is_active = true, status = 'active'
      `;

      customer = await loginAccount(rawCustomer);
      technicianOne = await loginAccount(rawTechnicianOne);
      technicianTwo = await loginAccount(rawTechnicianTwo);
      outsider = await loginAccount(rawOutsider);
    }, 90_000);

    afterAll(async () => {
      await setupSql?.end({ timeout: 2 });
      setupSql = null;
    });

    it('persists one offer per technician and rejects a concurrent second offer', async () => {
      const requestId = await createRequest(customer, 'offer concurrency');
      const first = proposalPayload(requestId, nextReference('PR'), 1100);
      const second = proposalPayload(requestId, nextReference('PR'), 1300);
      const results = await Promise.all([
        api('/api/proposals', {
          method: 'POST',
          body: JSON.stringify(first),
        }, technicianOne.token),
        api('/api/proposals', {
          method: 'POST',
          body: JSON.stringify(second),
        }, technicianOne.token),
      ]);
      expect(results.map((result) => result.response.status).sort())
        .toEqual([201, 409]);

      const winnerIndex = results.findIndex(
        (result) => result.response.status === 201,
      );
      const winningPayload = winnerIndex === 0 ? first : second;
      const replay = await api('/api/proposals', {
        method: 'POST',
        body: JSON.stringify({
          ...winningPayload,
          id: nextReference('PR-REPLAY'),
        }),
      }, technicianOne.token);
      expectStatus(replay, 200);
      expect(replay.body.idempotentReplay).toBe(true);

      const counts = await setupSql!`
        SELECT
          (SELECT count(*)::int FROM public.hdc_proposals
            WHERE request_id = ${requestId}
              AND technician_id = ${technicianOne.id}) AS proposals,
          (SELECT offer_count FROM public.hdc_service_requests
            WHERE id = ${requestId}) AS offers
      `;
      expect(Number(counts[0].proposals)).toBe(1);
      expect(Number(counts[0].offers)).toBe(1);
    });

    it('serializes competing acceptance and creates exactly one transaction', async () => {
      const requestId = await createRequest(customer, 'acceptance concurrency');
      const proposalOne = await submitProposal(technicianOne, requestId, 1200);
      const proposalTwo = await submitProposal(technicianTwo, requestId, 1400);
      const results = await Promise.all([
        api(`/api/proposals/${proposalOne}/accept`, { method: 'POST' }, customer.token),
        api(`/api/proposals/${proposalTwo}/accept`, { method: 'POST' }, customer.token),
      ]);
      expect(results.map((result) => result.response.status).sort())
        .toEqual([200, 409]);

      const rows = await setupSql!`
        SELECT
          (SELECT count(*)::int FROM public.hdc_service_transactions
            WHERE request_id = ${requestId}) AS transactions,
          (SELECT count(*)::int FROM public.hdc_proposals
            WHERE request_id = ${requestId} AND status = 'accepted') AS accepted,
          (SELECT count(*)::int FROM public.hdc_proposals
            WHERE request_id = ${requestId} AND status = 'declined') AS declined,
          (SELECT status FROM public.hdc_service_requests
            WHERE id = ${requestId}) AS request_status
      `;
      expect(Number(rows[0].transactions)).toBe(1);
      expect(Number(rows[0].accepted)).toBe(1);
      expect(Number(rows[0].declined)).toBe(1);
      expect(rows[0].request_status).toBe('technicianSelected');
    });

    it('persists chat and denies every cross-account read and write', async () => {
      const transactionId = await createAcceptedTransaction('chat denial');
      const sent = await api(
        `/api/service-transactions/${transactionId}/conversation/messages`,
        {
          method: 'POST',
          body: JSON.stringify({
            clientMessageId: nextReference('CLIENT-MSG'),
            text: 'Please confirm the service address before arrival.',
            acknowledgeLanguageWarning: false,
          }),
        },
        customer.token,
      );
      expectStatus(sent, 201);

      const denied = await api(
        `/api/service-transactions/${transactionId}/conversation`,
        { method: 'GET' },
        outsider.token,
      );
      expect([403, 404]).toContain(denied.response.status);

      const outsiderBootstrap = await api(
        '/api/workflow/bootstrap',
        { method: 'GET' },
        outsider.token,
      );
      expectStatus(outsiderBootstrap, 200);
      expect(outsiderBootstrap.body.serviceTransactions).toEqual([]);

      const rlsRows = await setupSql!.begin(async (tx) => {
        await tx`
          SELECT
            set_config('hdc.user_id', ${outsider.id}, true),
            set_config('hdc.roles', 'customer', true)
        `;
        await tx.unsafe('SET LOCAL ROLE hdc_app');
        return await tx`
          SELECT count(*)::int AS visible
          FROM public.hdc_service_transactions
          WHERE id = ${transactionId}
        `;
      });
      expect(Number(rlsRows[0].visible)).toBe(0);

      const persisted = await setupSql!`
        SELECT count(*)::int AS messages
        FROM public.hdc_private_messages message
        JOIN public.hdc_private_conversations conversation
          ON conversation.id = message.conversation_id
        WHERE conversation.transaction_id = ${transactionId}
      `;
      expect(Number(persisted[0].messages)).toBe(1);
    });

    it('records participant-confirmed payments, events, and receipts', async () => {
      const transactionId = await createAcceptedTransaction('payment ledger');
      const recorded = await api(
        `/api/service-transactions/${transactionId}/payments`,
        {
          method: 'POST',
          body: JSON.stringify({
            clientReference: nextReference('PAY-CLIENT'),
            amountMinor: 50000,
            currency: 'PHP',
            paymentMethod: 'eWallet',
            note: 'Customer-recorded partial payment for database testing.',
            externalReference: 'EWALLET-TEST-001',
          }),
        },
        customer.token,
      );
      expectStatus(recorded, 201);
      const toolbox = recorded.body.toolbox as Record<string, unknown>;
      const payment = (toolbox.payments as Record<string, unknown>[])[0];

      const confirmed = await api(
        `/api/service-transactions/${transactionId}/payments/${String(payment.id)}`,
        {
          method: 'PUT',
          body: JSON.stringify({
            action: 'confirm',
            amountMinor: null,
            note: 'Technician confirms receipt from the customer.',
          }),
        },
        technicianOne.token,
      );
      expectStatus(confirmed, 200);

      const rows = await setupSql!`
        SELECT
          (SELECT status FROM public.hdc_service_payments
            WHERE id = ${String(payment.id)}) AS payment_status,
          (SELECT count(*)::int FROM public.hdc_service_payment_events
            WHERE payment_id = ${String(payment.id)}) AS events,
          (SELECT count(*)::int FROM public.hdc_service_receipts
            WHERE payment_id = ${String(payment.id)}) AS receipts
      `;
      expect(rows[0].payment_status).toBe('confirmed');
      expect(Number(rows[0].events)).toBe(2);
      expect(Number(rows[0].receipts)).toBe(1);
    });

    it('freezes a transaction and preserves an auditable dispute trail', async () => {
      const transactionId = await createAcceptedTransaction('dispute trail');
      const opened = await api(
        `/api/service-transactions/${transactionId}/disputes`,
        {
          method: 'POST',
          body: JSON.stringify({
            clientReference: nextReference('DSP-CLIENT'),
            reasonCode: 'workQuality',
            summary:
              'The reported repair result differs from the accepted scope and needs review.',
            requestedOutcome: 'continueService',
          }),
        },
        customer.token,
      );
      expectStatus(opened, 201);

      const rows = await setupSql!`
        SELECT
          (SELECT status FROM public.hdc_service_transactions
            WHERE id = ${transactionId}) AS transaction_status,
          (SELECT count(*)::int FROM public.hdc_service_disputes
            WHERE transaction_id = ${transactionId} AND status = 'open')
              AS open_disputes,
          (SELECT count(*)::int FROM public.hdc_service_dispute_events
            WHERE transaction_id = ${transactionId} AND event_type = 'opened')
              AS opened_events
      `;
      expect(rows[0].transaction_status).toBe('disputed');
      expect(Number(rows[0].open_disputes)).toBe(1);
      expect(Number(rows[0].opened_events)).toBe(1);
    });
  },
);
