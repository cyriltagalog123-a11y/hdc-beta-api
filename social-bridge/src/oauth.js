import crypto from 'node:crypto';
import { secureEqual } from './security.js';

const ACCESS_TOKEN_TTL_SECONDS = 60 * 60;
const REFRESH_TOKEN_TTL_SECONDS = 30 * 24 * 60 * 60;
const CODE_TTL_SECONDS = 10 * 60;

export const OAUTH_SCOPES = ['social.read', 'social.publish'];

export function publicBaseUrl() {
  return String(process.env.PUBLIC_BASE_URL || 'https://hdc-social-bridge-production.up.railway.app').replace(/\/$/, '');
}

export function mcpResource() {
  return `${publicBaseUrl()}/mcp`;
}

export function tokenHash(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function randomToken(bytes = 32) {
  return crypto.randomBytes(bytes).toString('base64url');
}

function normalizeScopes(scope) {
  const requested = String(scope || '').trim().split(/\s+/).filter(Boolean);
  const unique = [...new Set(requested.length ? requested : ['social.read'])];
  if (unique.some((item) => !OAUTH_SCOPES.includes(item))) {
    throw new Error('invalid_scope');
  }
  return unique;
}

function safeRedirectUrl(value) {
  const url = new URL(String(value));
  if (url.protocol !== 'https:' && url.hostname !== 'localhost' && url.hostname !== '127.0.0.1') {
    throw new Error('invalid_redirect_uri');
  }
  return url.toString();
}

function verifyPkce(verifier, challenge) {
  if (!verifier || !challenge) return false;
  const digest = crypto.createHash('sha256').update(String(verifier)).digest('base64url');
  return secureEqual(digest, challenge);
}

function appendQuery(urlString, values) {
  const url = new URL(urlString);
  for (const [key, value] of Object.entries(values)) {
    if (value !== undefined && value !== null && value !== '') url.searchParams.set(key, String(value));
  }
  return url.toString();
}

function htmlEscape(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function renderAuthorizePage(params, error = '') {
  const hidden = Object.entries(params)
    .filter(([, value]) => value !== undefined && value !== null)
    .map(([key, value]) => `<input type="hidden" name="${htmlEscape(key)}" value="${htmlEscape(value)}">`)
    .join('');
  return `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Authorize HDC Social Bridge</title>
<style>body{font-family:system-ui;background:#07111f;color:#eef6ff;display:grid;place-items:center;min-height:100vh;margin:0}.card{width:min(520px,90vw);background:#0d1b2e;padding:28px;border-radius:16px;border:1px solid #1f3654}label{display:block;margin:12px 0 6px}input{width:100%;box-sizing:border-box;padding:11px;border-radius:8px;border:1px solid #365578;background:#07111f;color:#fff}button{margin-top:18px;width:100%;padding:12px;border:0;border-radius:8px;font-weight:700;background:#2e8bff;color:#fff}.muted{color:#a9bdd3;font-size:14px}.error{color:#ff9d9d}</style></head>
<body><main class="card"><h1>Connect HDC Social Bridge</h1><p class="muted">Authorize ChatGPT to read the connected HDC Page and publish only when you explicitly approve a post.</p>${error ? `<p class="error">${htmlEscape(error)}</p>` : ''}<form method="post" action="/oauth/authorize">${hidden}<label>Admin username</label><input name="username" autocomplete="username" required><label>Admin password</label><input name="password" type="password" autocomplete="current-password" required><button type="submit">Authorize connection</button></form></main></body></html>`;
}

export function oauthMetadata() {
  const base = publicBaseUrl();
  return {
    issuer: base,
    authorization_response_iss_parameter_supported: true,
    authorization_endpoint: `${base}/oauth/authorize`,
    token_endpoint: `${base}/oauth/token`,
    registration_endpoint: `${base}/oauth/register`,
    response_types_supported: ['code'],
    grant_types_supported: ['authorization_code', 'refresh_token'],
    token_endpoint_auth_methods_supported: ['none'],
    code_challenge_methods_supported: ['S256'],
    scopes_supported: OAUTH_SCOPES
  };
}

export function protectedResourceMetadata() {
  const base = publicBaseUrl();
  return {
    resource: mcpResource(),
    authorization_servers: [base],
    scopes_supported: OAUTH_SCOPES,
    resource_documentation: `${base}/docs/mcp`,
    resource_policy_uri: `${base}/privacy`,
    resource_tos_uri: `${base}/terms`
  };
}

export async function registerClient(req, res, store) {
  try {
    const redirectUris = Array.isArray(req.body?.redirect_uris) ? req.body.redirect_uris.map(safeRedirectUrl) : [];
    if (!redirectUris.length) return res.status(400).json({ error: 'invalid_client_metadata', error_description: 'redirect_uris is required' });
    if (req.body?.token_endpoint_auth_method && req.body.token_endpoint_auth_method !== 'none') {
      return res.status(400).json({ error: 'invalid_client_metadata', error_description: 'Only public clients using token_endpoint_auth_method=none are supported' });
    }
    const clientId = `hdc_${randomToken(24)}`;
    const client = {
      clientId,
      clientName: String(req.body?.client_name || 'OpenAI MCP Client').slice(0, 200),
      redirectUris,
      createdAt: new Date().toISOString()
    };
    await store.saveOAuthClient(client);
    return res.status(201).json({
      client_id: clientId,
      client_name: client.clientName,
      redirect_uris: redirectUris,
      token_endpoint_auth_method: 'none',
      grant_types: ['authorization_code', 'refresh_token'],
      response_types: ['code']
    });
  } catch (error) {
    return res.status(400).json({ error: 'invalid_client_metadata', error_description: error.message });
  }
}

async function validateAuthorizationRequest(params, store) {
  if (params.response_type !== 'code') throw new Error('unsupported_response_type');
  if (!params.client_id) throw new Error('invalid_request');
  const client = await store.getOAuthClient(params.client_id);
  if (!client) throw new Error('unauthorized_client');
  const redirectUri = safeRedirectUrl(params.redirect_uri);
  if (!client.redirectUris.includes(redirectUri)) throw new Error('invalid_redirect_uri');
  if (params.code_challenge_method !== 'S256' || !params.code_challenge) throw new Error('invalid_request');
  if (params.resource !== mcpResource()) throw new Error('invalid_target');
  return { client, redirectUri, scopes: normalizeScopes(params.scope) };
}

export async function authorizeGet(req, res, store) {
  const params = {
    response_type: String(req.query.response_type || ''),
    client_id: String(req.query.client_id || ''),
    redirect_uri: String(req.query.redirect_uri || ''),
    code_challenge: String(req.query.code_challenge || ''),
    code_challenge_method: String(req.query.code_challenge_method || ''),
    scope: String(req.query.scope || ''),
    state: String(req.query.state || ''),
    resource: String(req.query.resource || '')
  };
  try {
    await validateAuthorizationRequest(params, store);
    return res.type('html').send(renderAuthorizePage(params));
  } catch (error) {
    if (params.redirect_uri && params.state) {
      try {
        return res.redirect(appendQuery(params.redirect_uri, { error: error.message, state: params.state, iss: publicBaseUrl() }));
      } catch {}
    }
    return res.status(400).send(`OAuth authorization request rejected: ${error.message}`);
  }
}

export async function authorizePost(req, res, store) {
  const params = {
    response_type: String(req.body.response_type || ''),
    client_id: String(req.body.client_id || ''),
    redirect_uri: String(req.body.redirect_uri || ''),
    code_challenge: String(req.body.code_challenge || ''),
    code_challenge_method: String(req.body.code_challenge_method || ''),
    scope: String(req.body.scope || ''),
    state: String(req.body.state || ''),
    resource: String(req.body.resource || '')
  };
  try {
    const { redirectUri, scopes } = await validateAuthorizationRequest(params, store);
    if (!secureEqual(req.body.username, process.env.ADMIN_USERNAME) || !secureEqual(req.body.password, process.env.ADMIN_PASSWORD)) {
      return res.status(401).type('html').send(renderAuthorizePage(params, 'Invalid administrator credentials.'));
    }
    const code = randomToken(32);
    await store.saveOAuthCode({
      codeHash: tokenHash(code),
      clientId: params.client_id,
      redirectUri,
      codeChallenge: params.code_challenge,
      scopes,
      resource: params.resource,
      expiresAt: new Date(Date.now() + CODE_TTL_SECONDS * 1000).toISOString()
    });
    return res.redirect(appendQuery(redirectUri, { code, state: params.state, iss: publicBaseUrl() }));
  } catch (error) {
    return res.status(400).send(`OAuth authorization failed: ${error.message}`);
  }
}

async function issueTokens(store, { clientId, scopes, resource }) {
  const accessToken = randomToken(32);
  const refreshToken = randomToken(40);
  const now = Date.now();
  await store.saveOAuthToken({
    tokenHash: tokenHash(accessToken),
    refreshHash: tokenHash(refreshToken),
    clientId,
    scopes,
    resource,
    accessExpiresAt: new Date(now + ACCESS_TOKEN_TTL_SECONDS * 1000).toISOString(),
    refreshExpiresAt: new Date(now + REFRESH_TOKEN_TTL_SECONDS * 1000).toISOString()
  });
  return {
    access_token: accessToken,
    token_type: 'Bearer',
    expires_in: ACCESS_TOKEN_TTL_SECONDS,
    refresh_token: refreshToken,
    scope: scopes.join(' ')
  };
}

export async function tokenEndpoint(req, res, store) {
  try {
    const grantType = String(req.body.grant_type || '');
    const clientId = String(req.body.client_id || '');
    const client = await store.getOAuthClient(clientId);
    if (!client) return res.status(401).json({ error: 'invalid_client' });

    if (grantType === 'authorization_code') {
      const codeHash = tokenHash(req.body.code || '');
      const record = await store.consumeOAuthCode(codeHash);
      if (!record || new Date(record.expiresAt).getTime() <= Date.now()) return res.status(400).json({ error: 'invalid_grant' });
      const redirectUri = safeRedirectUrl(req.body.redirect_uri);
      if (record.clientId !== clientId || record.redirectUri !== redirectUri || record.resource !== String(req.body.resource || '')) {
        return res.status(400).json({ error: 'invalid_grant' });
      }
      if (!verifyPkce(req.body.code_verifier, record.codeChallenge)) return res.status(400).json({ error: 'invalid_grant' });
      return res.json(await issueTokens(store, record));
    }

    if (grantType === 'refresh_token') {
      const existing = await store.getOAuthTokenByRefreshHash(tokenHash(req.body.refresh_token || ''));
      if (!existing || existing.clientId !== clientId || new Date(existing.refreshExpiresAt).getTime() <= Date.now()) {
        return res.status(400).json({ error: 'invalid_grant' });
      }
      const resource = String(req.body.resource || existing.resource);
      if (resource !== existing.resource) return res.status(400).json({ error: 'invalid_target' });
      const scopes = normalizeScopes(req.body.scope || existing.scopes.join(' '));
      if (scopes.some((scope) => !existing.scopes.includes(scope))) return res.status(400).json({ error: 'invalid_scope' });
      await store.revokeOAuthToken(existing.tokenHash);
      return res.json(await issueTokens(store, { clientId, scopes, resource }));
    }

    return res.status(400).json({ error: 'unsupported_grant_type' });
  } catch (error) {
    return res.status(400).json({ error: 'invalid_request', error_description: error.message });
  }
}

export async function authenticateBearer(req, store) {
  const header = String(req.headers.authorization || '');
  if (!/^Bearer\s+/i.test(header)) return null;
  const token = header.replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const record = await store.getOAuthTokenByAccessHash(tokenHash(token));
  if (!record || new Date(record.accessExpiresAt).getTime() <= Date.now()) return null;
  if (record.resource !== mcpResource()) return null;
  return record;
}

export function authChallenge(scope = 'social.read', description = 'Connect HDC Social Bridge to continue') {
  const metadata = `${publicBaseUrl()}/.well-known/oauth-protected-resource`;
  return `Bearer resource_metadata="${metadata}", scope="${scope}", error="insufficient_scope", error_description="${description}"`;
}
