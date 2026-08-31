import { describe, expect, it } from 'vitest';

import { handleHdcApiRequest } from '../netlify/functions/api.mjs';

const runLiveIntegration = process.env.HDC_LIVE_INTEGRATION === '1';

async function api(
  path: string,
  init: RequestInit = {},
): Promise<{ response: Response; body: Record<string, unknown> }> {
  const response = await handleHdcApiRequest(
    new Request(`https://hdc-build23.test${path}`, {
      ...init,
      headers: {
        accept: 'application/json',
        'content-type': 'application/json',
        ...(init.headers ?? {}),
      },
    }),
  );
  const body = await response.json() as Record<string, unknown>;
  return { response, body };
}

describe.skipIf(!runLiveIntegration)('isolated service-request integration', () => {
  it('registers, signs in, and reloads complete request history', async () => {
    const unique = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const email = `hdc-build23-${unique}@example.invalid`;
    const password = 'Build20!Isolated-Test-4829';

    const registration = await api('/api/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        email,
        password,
        displayName: 'Build 23 Integration Tester',
        recoveryAnswers: [
          { questionCode: 'first_meal', answer: 'ginger rice porridge' },
          { questionCode: 'childhood_nickname', answer: 'quiet comet' },
          { questionCode: 'private_phrase', answer: 'amber harbor lantern' },
        ],
        termsAccepted: true,
        privacyAcknowledged: true,
        termsVersion: 'beta-2026-08-29',
      }),
    });
    expect(registration.response.status, JSON.stringify(registration.body))
      .toBe(201);

    const login = await api('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    expect(login.response.status, JSON.stringify(login.body)).toBe(200);
    expect(login.body.token).toEqual(expect.any(String));

    const token = String(login.body.token);
    const requestIds = [0, 1, 2].map(
      (index) => `SR-${Date.now()}-${index}`,
    );
    for (const [index, requestId] of requestIds.entries()) {
      const created = await api('/api/service-requests', {
        method: 'POST',
        headers: { authorization: `Bearer ${token}` },
        body: JSON.stringify({
          id: requestId,
          customerId: 'ignored-client-identity',
          customerName: 'Ignored Client Name',
          title: `Laptop showing a blue screen ${index + 1}`,
          categoryId: 'laptop_repair',
          categoryName: 'Laptop Repair',
          description:
            'Blue screen when booting. Reboot has been done and cleaning is done too.',
          location: 'Cebu City',
          preferredDate: '2026-09-05T00:00:00.000',
          preferredTime: 'Any time',
          urgency: 'normal',
          minimumBudget: null,
          maximumBudget: null,
          status: 'open',
          offerCount: 0,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }),
      });
      expect(created.response.status, JSON.stringify(created.body)).toBe(201);
      expect(created.body.serviceRequest).toMatchObject({
        id: requestId,
        status: 'open',
      });
    }

    const bootstrap = await api('/api/workflow/bootstrap', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(bootstrap.response.status, JSON.stringify(bootstrap.body)).toBe(200);
    expect(bootstrap.body.serviceRequests).toEqual(expect.arrayContaining(
      requestIds.map((id) => expect.objectContaining({ id })),
    ));
  }, 60_000);
});
