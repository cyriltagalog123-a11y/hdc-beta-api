import crypto from 'node:crypto';
import { mcpResource, publicBaseUrl } from './oauth.js';

function randomUrlSafe(bytes = 32) {
  return crypto.randomBytes(bytes).toString('base64url');
}

function pkceChallenge(verifier) {
  return crypto.createHash('sha256').update(verifier).digest('base64url');
}

async function jsonOrText(response) {
  const text = await response.text();
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return text;
  }
}

function expect(condition, message, details = null) {
  if (!condition) {
    const error = new Error(message);
    error.details = details;
    throw error;
  }
}

export async function runOAuthMcpSmokeTest() {
  const localBase = `http://127.0.0.1:${Number(process.env.PORT || 8787)}`;
  const redirectUri = 'https://client.example.invalid/callback';
  const resource = mcpResource();
  const verifier = randomUrlSafe(48);
  const challenge = pkceChallenge(verifier);
  const state = randomUrlSafe(18);
  const steps = [];

  const registrationResponse = await fetch(`${localBase}/oauth/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      client_name: 'HDC Social Bridge OAuth MCP Smoke Test',
      redirect_uris: [redirectUri],
      token_endpoint_auth_method: 'none'
    })
  });
  const registration = await jsonOrText(registrationResponse);
  expect(registrationResponse.status === 201 && registration?.client_id, 'Dynamic client registration failed', {
    status: registrationResponse.status,
    response: registration
  });
  steps.push({ step: 'dynamic_client_registration', ok: true, status: registrationResponse.status });

  const authorizeQuery = new URLSearchParams({
    response_type: 'code',
    client_id: registration.client_id,
    redirect_uri: redirectUri,
    code_challenge: challenge,
    code_challenge_method: 'S256',
    scope: 'social.read social.publish',
    state,
    resource
  });

  const authorizePageResponse = await fetch(`${localBase}/oauth/authorize?${authorizeQuery}`);
  const authorizePage = await authorizePageResponse.text();
  expect(authorizePageResponse.status === 200 && authorizePage.includes('Authorize HDC Social Bridge'), 'Authorization UI check failed', {
    status: authorizePageResponse.status
  });
  steps.push({ step: 'authorization_ui', ok: true, status: authorizePageResponse.status });

  const authorizeBody = new URLSearchParams({
    response_type: 'code',
    client_id: registration.client_id,
    redirect_uri: redirectUri,
    code_challenge: challenge,
    code_challenge_method: 'S256',
    scope: 'social.read social.publish',
    state,
    resource,
    username: String(process.env.ADMIN_USERNAME || ''),
    password: String(process.env.ADMIN_PASSWORD || '')
  });

  const authorizeResponse = await fetch(`${localBase}/oauth/authorize`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: authorizeBody,
    redirect: 'manual'
  });
  const location = authorizeResponse.headers.get('location');
  expect(authorizeResponse.status >= 300 && authorizeResponse.status < 400 && location, 'Authorization code redirect failed', {
    status: authorizeResponse.status
  });
  const callback = new URL(location);
  const code = callback.searchParams.get('code');
  expect(code && callback.searchParams.get('state') === state, 'Authorization code/state validation failed');
  steps.push({ step: 'authorization_code', ok: true, status: authorizeResponse.status });

  const tokenBody = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: registration.client_id,
    code,
    redirect_uri: redirectUri,
    code_verifier: verifier,
    resource
  });
  const tokenResponse = await fetch(`${localBase}/oauth/token`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: tokenBody
  });
  const tokens = await jsonOrText(tokenResponse);
  expect(tokenResponse.status === 200 && tokens?.access_token && tokens?.refresh_token, 'Authorization code token exchange failed', {
    status: tokenResponse.status,
    response: tokens
  });
  expect(String(tokens.scope || '').includes('social.read') && String(tokens.scope || '').includes('social.publish'), 'Issued token is missing required scopes', tokens);
  steps.push({ step: 'pkce_token_exchange', ok: true, status: tokenResponse.status });

  const mcpHeaders = {
    authorization: `Bearer ${tokens.access_token}`,
    'content-type': 'application/json',
    accept: 'application/json, text/event-stream'
  };

  const initializeResponse = await fetch(`${localBase}/mcp`, {
    method: 'POST',
    headers: mcpHeaders,
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: 1,
      method: 'initialize',
      params: {
        protocolVersion: '2025-06-18',
        capabilities: {},
        clientInfo: { name: 'hdc-social-bridge-smoke', version: '0.2.0' }
      }
    })
  });
  const initialize = await jsonOrText(initializeResponse);
  expect(initializeResponse.status === 200 && initialize?.result?.serverInfo?.name === 'hdc-social-bridge', 'MCP initialize failed', {
    status: initializeResponse.status,
    response: initialize
  });
  steps.push({ step: 'mcp_initialize', ok: true, status: initializeResponse.status, protocolVersion: initialize?.result?.protocolVersion || null });

  const toolsResponse = await fetch(`${localBase}/mcp`, {
    method: 'POST',
    headers: mcpHeaders,
    body: JSON.stringify({ jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} })
  });
  const toolsResult = await jsonOrText(toolsResponse);
  const toolNames = Array.isArray(toolsResult?.result?.tools) ? toolsResult.result.tools.map((tool) => tool.name) : [];
  expect(toolsResponse.status === 200 && toolNames.includes('publish_text_post') && toolNames.includes('list_connected_pages'), 'MCP tools/list failed or required tools are missing', {
    status: toolsResponse.status,
    response: toolsResult
  });
  steps.push({ step: 'mcp_tools_list', ok: true, status: toolsResponse.status, tools: toolNames });

  const profileResponse = await fetch(`${localBase}/mcp`, {
    method: 'POST',
    headers: mcpHeaders,
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: 3,
      method: 'tools/call',
      params: { name: 'get_account_profile', arguments: {} }
    })
  });
  const profile = await jsonOrText(profileResponse);
  expect(profileResponse.status === 200 && profile?.result && profile.result.isError !== true, 'Authenticated MCP read tool call failed', {
    status: profileResponse.status,
    response: profile
  });
  steps.push({ step: 'authenticated_read_tool', ok: true, status: profileResponse.status });

  const blockedPublishResponse = await fetch(`${localBase}/mcp`, {
    method: 'POST',
    headers: mcpHeaders,
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: 4,
      method: 'tools/call',
      params: {
        name: 'publish_text_post',
        arguments: { pageId: 'smoke-test-page', message: 'This must not publish.', confirm: false }
      }
    })
  });
  const blockedPublish = await jsonOrText(blockedPublishResponse);
  expect(blockedPublishResponse.status === 200 && blockedPublish?.result?.isError === true, 'Publish confirmation safety gate did not block the test write', {
    status: blockedPublishResponse.status,
    response: blockedPublish
  });
  steps.push({ step: 'publish_confirmation_gate', ok: true, status: blockedPublishResponse.status });

  const refreshBody = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: registration.client_id,
    refresh_token: tokens.refresh_token,
    resource,
    scope: 'social.read social.publish'
  });
  const refreshResponse = await fetch(`${localBase}/oauth/token`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: refreshBody
  });
  const refreshed = await jsonOrText(refreshResponse);
  expect(refreshResponse.status === 200 && refreshed?.access_token && refreshed?.refresh_token, 'Refresh-token rotation failed', {
    status: refreshResponse.status,
    response: refreshed
  });
  steps.push({ step: 'refresh_token_rotation', ok: true, status: refreshResponse.status });

  return {
    ok: true,
    version: '0.2.0',
    issuer: publicBaseUrl(),
    resource,
    steps
  };
}
