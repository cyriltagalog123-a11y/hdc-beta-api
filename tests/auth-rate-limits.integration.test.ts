import { randomUUID } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { handleHdcApiRequest } from '../netlify/functions/api.mjs';

const password = 'HdcIsolated!Security-4829';
const answers = [
  { questionCode: 'first_meal', answer: 'saffron rice with ginger' },
  { questionCode: 'childhood_nickname', answer: 'quiet violet comet' },
  { questionCode: 'private_phrase', answer: 'safe harbor by the moon' },
];
const wrongAnswers = answers.map((item) => ({ ...item, answer: `incorrect ${item.questionCode}` }));

async function call(path: string, body: Record<string, unknown>, token?: string) {
  const response = await handleHdcApiRequest(new Request(`https://hdc-auth.test${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  }));
  return { status: response.status, body: await response.json() as Record<string, unknown> };
}

async function account() {
  const email = `rate-limit-${randomUUID()}@example.invalid`;
  const registered = await call('/api/auth/register', {
    email, password, displayName: 'Isolated security check',
    location: 'Cebu City, Central Visayas, Philippines', recoveryAnswers: answers,
    termsAccepted: true, privacyAcknowledged: true, termsVersion: 'beta-2026-09-06',
  });
  expect(registered.status, JSON.stringify(registered.body)).toBe(201);
  const login = await call('/api/auth/login', { email, password });
  expect(login.status).toBe(200);
  return { email, token: String(login.body.token) };
}

describe.skipIf(process.env.HDC_POSTGRES_INTEGRATION !== '1').sequential('Concurrent authentication limits', () => {
  it('allows only the final remaining login attempt across concurrent requests', async () => {
    const member = await account();
    const wrong = () => call('/api/auth/login', { email: member.email, password: 'wrong-password' });
    for (let i = 0; i < 4; i++) expect((await wrong()).status).toBe(401);
    const results = await Promise.all(Array.from({ length: 4 }, wrong));
    expect(results.map((r) => r.status).sort()).toEqual([401, 429, 429, 429]);
    expect((await call('/api/auth/login', { email: member.email, password })).status).toBe(429);
    expect((await call('/api/auth/recovery/verify', { email: member.email, answers })).status).toBe(200);
  }, 30000);

  it('keeps recovery attempts inside the limit when requests arrive together', async () => {
    const member = await account();
    const wrong = () => call('/api/auth/recovery/verify', { email: member.email, answers: wrongAnswers });
    for (let i = 0; i < 4; i++) expect((await wrong()).status).toBe(202);
    const results = await Promise.all(Array.from({ length: 4 }, wrong));
    expect(results.map((r) => r.status).sort()).toEqual([202, 429, 429, 429]);
    expect(results.every((r) => !('resetToken' in r.body))).toBe(true);
    expect((await call('/api/auth/recovery/verify', { email: member.email, answers })).status).toBe(429);
    expect((await call('/api/auth/login', { email: member.email, password })).status).toBe(200);
  }, 30000);

  it('serializes current-password failures for recovery-answer changes', async () => {
    const member = await account();
    const wrong = () => call('/api/auth/recovery/answers', {
      currentPassword: 'wrong-password', recoveryAnswers: answers,
    }, member.token);
    for (let i = 0; i < 4; i++) expect((await wrong()).status).toBe(401);
    const results = await Promise.all(Array.from({ length: 4 }, wrong));
    expect(results.map((r) => r.status).sort()).toEqual([401, 429, 429, 429]);
    expect((await call('/api/auth/recovery/answers', {
      currentPassword: password, recoveryAnswers: answers,
    }, member.token)).status).toBe(429);
  }, 30000);

  it('commits successful recovery-answer changes and returns one-time recovery credentials', async () => {
    const member = await account();
    const updated = answers.map((item) => ({ ...item, answer: `new ${item.answer}` }));
    expect((await call('/api/auth/recovery/answers', {
      currentPassword: password, recoveryAnswers: updated,
    }, member.token)).status).toBe(200);
    const recovery = await call('/api/auth/recovery/verify', { email: member.email, answers: updated });
    expect(recovery.status, JSON.stringify(recovery.body)).toBe(200);
    expect(recovery.body.result).toBe('verified');
    expect(recovery.body.resetToken).toEqual(expect.any(String));
  }, 30000);
});
