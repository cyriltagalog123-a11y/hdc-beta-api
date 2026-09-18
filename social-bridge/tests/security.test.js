import test from 'node:test';
import assert from 'node:assert/strict';

process.env.TOKEN_ENCRYPTION_KEY = '11'.repeat(32);
process.env.STATE_SECRET = 'test-state-secret';

const { encryptToken, decryptToken, createOAuthState, verifyOAuthState } = await import('../src/security.js');

test('token encryption round trip', () => {
  const token = 'page-secret-token';
  const encrypted = encryptToken(token);
  assert.notEqual(encrypted, token);
  assert.equal(decryptToken(encrypted), token);
});

test('OAuth state is signed and verifiable', () => {
  const state = createOAuthState();
  assert.equal(verifyOAuthState(state), true);
  assert.equal(verifyOAuthState(`${state}x`), false);
});
