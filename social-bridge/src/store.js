import pg from 'pg';
import { encryptToken, decryptToken } from './security.js';

const { Pool } = pg;

class MemoryStore {
  constructor() {
    this.pages = new Map();
    this.audit = [];
    this.oauthClients = new Map();
    this.oauthCodes = new Map();
    this.oauthTokens = new Map();
    this.oauthRefresh = new Map();
  }

  async init() {}

  async savePage(page) {
    this.pages.set(page.id, {
      pageId: page.id,
      pageName: page.name,
      tokenCipher: encryptToken(page.accessToken),
      tasks: page.tasks || [],
      connectedAt: new Date().toISOString()
    });
  }

  async listPages() {
    return [...this.pages.values()].map(({ tokenCipher, ...page }) => page);
  }

  async getPage(pageId) {
    const page = this.pages.get(String(pageId));
    if (!page) return null;
    return { ...page, accessToken: decryptToken(page.tokenCipher) };
  }

  async addAudit(entry) {
    this.audit.unshift({ ...entry, createdAt: new Date().toISOString() });
    this.audit = this.audit.slice(0, 100);
  }

  async listAudit(limit = 25) {
    return this.audit.slice(0, limit);
  }

  async saveOAuthClient(client) {
    this.oauthClients.set(client.clientId, { ...client });
  }

  async getOAuthClient(clientId) {
    return this.oauthClients.get(String(clientId)) || null;
  }

  async saveOAuthCode(code) {
    this.oauthCodes.set(code.codeHash, { ...code, consumed: false });
  }

  async consumeOAuthCode(codeHash) {
    const record = this.oauthCodes.get(String(codeHash));
    if (!record || record.consumed) return null;
    record.consumed = true;
    return { ...record };
  }

  async saveOAuthToken(token) {
    this.oauthTokens.set(token.tokenHash, { ...token });
    this.oauthRefresh.set(token.refreshHash, token.tokenHash);
  }

  async getOAuthTokenByAccessHash(accessHash) {
    return this.oauthTokens.get(String(accessHash)) || null;
  }

  async getOAuthTokenByRefreshHash(refreshHash) {
    const accessHash = this.oauthRefresh.get(String(refreshHash));
    return accessHash ? this.oauthTokens.get(accessHash) || null : null;
  }

  async revokeOAuthToken(accessHash) {
    const record = this.oauthTokens.get(String(accessHash));
    if (record?.refreshHash) this.oauthRefresh.delete(record.refreshHash);
    this.oauthTokens.delete(String(accessHash));
  }
}

class PostgresStore {
  constructor(connectionString) {
    const ssl = String(process.env.DATABASE_SSL || 'true').toLowerCase() === 'true'
      ? { rejectUnauthorized: false }
      : false;
    this.pool = new Pool({ connectionString, ssl });
  }

  async init() {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS social_bridge_connections (
        page_id TEXT PRIMARY KEY,
        page_name TEXT NOT NULL,
        token_cipher TEXT NOT NULL,
        tasks JSONB NOT NULL DEFAULT '[]'::jsonb,
        connected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE TABLE IF NOT EXISTS social_bridge_audit (
        id BIGSERIAL PRIMARY KEY,
        action TEXT NOT NULL,
        page_id TEXT,
        payload JSONB NOT NULL DEFAULT '{}'::jsonb,
        success BOOLEAN NOT NULL,
        result JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE TABLE IF NOT EXISTS social_bridge_oauth_clients (
        client_id TEXT PRIMARY KEY,
        client_name TEXT NOT NULL,
        redirect_uris JSONB NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE TABLE IF NOT EXISTS social_bridge_oauth_codes (
        code_hash TEXT PRIMARY KEY,
        client_id TEXT NOT NULL,
        redirect_uri TEXT NOT NULL,
        code_challenge TEXT NOT NULL,
        scopes JSONB NOT NULL,
        resource TEXT NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        consumed BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE TABLE IF NOT EXISTS social_bridge_oauth_tokens (
        token_hash TEXT PRIMARY KEY,
        refresh_hash TEXT UNIQUE NOT NULL,
        client_id TEXT NOT NULL,
        scopes JSONB NOT NULL,
        resource TEXT NOT NULL,
        access_expires_at TIMESTAMPTZ NOT NULL,
        refresh_expires_at TIMESTAMPTZ NOT NULL,
        revoked BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS social_bridge_oauth_refresh_idx
        ON social_bridge_oauth_tokens (refresh_hash);
    `);
  }

  async savePage(page) {
    await this.pool.query(`
      INSERT INTO social_bridge_connections (page_id, page_name, token_cipher, tasks, connected_at)
      VALUES ($1, $2, $3, $4::jsonb, NOW())
      ON CONFLICT (page_id) DO UPDATE SET
        page_name = EXCLUDED.page_name,
        token_cipher = EXCLUDED.token_cipher,
        tasks = EXCLUDED.tasks,
        connected_at = NOW()
    `, [page.id, page.name, encryptToken(page.accessToken), JSON.stringify(page.tasks || [])]);
  }

  async listPages() {
    const result = await this.pool.query(`
      SELECT page_id AS "pageId", page_name AS "pageName", tasks,
             connected_at AS "connectedAt"
      FROM social_bridge_connections
      ORDER BY connected_at DESC
    `);
    return result.rows;
  }

  async getPage(pageId) {
    const result = await this.pool.query(`
      SELECT page_id AS "pageId", page_name AS "pageName", token_cipher AS "tokenCipher",
             tasks, connected_at AS "connectedAt"
      FROM social_bridge_connections
      WHERE page_id = $1
    `, [String(pageId)]);
    if (!result.rows[0]) return null;
    const row = result.rows[0];
    return { ...row, accessToken: decryptToken(row.tokenCipher) };
  }

  async addAudit(entry) {
    await this.pool.query(`
      INSERT INTO social_bridge_audit (action, page_id, payload, success, result)
      VALUES ($1, $2, $3::jsonb, $4, $5::jsonb)
    `, [
      entry.action,
      entry.pageId || null,
      JSON.stringify(entry.payload || {}),
      Boolean(entry.success),
      JSON.stringify(entry.result || {})
    ]);
  }

  async listAudit(limit = 25) {
    const result = await this.pool.query(`
      SELECT id, action, page_id AS "pageId", payload, success, result,
             created_at AS "createdAt"
      FROM social_bridge_audit
      ORDER BY created_at DESC
      LIMIT $1
    `, [Math.min(Math.max(Number(limit) || 25, 1), 100)]);
    return result.rows;
  }

  async saveOAuthClient(client) {
    await this.pool.query(`
      INSERT INTO social_bridge_oauth_clients (client_id, client_name, redirect_uris)
      VALUES ($1, $2, $3::jsonb)
      ON CONFLICT (client_id) DO UPDATE SET
        client_name = EXCLUDED.client_name,
        redirect_uris = EXCLUDED.redirect_uris
    `, [client.clientId, client.clientName, JSON.stringify(client.redirectUris)]);
  }

  async getOAuthClient(clientId) {
    const result = await this.pool.query(`
      SELECT client_id AS "clientId", client_name AS "clientName", redirect_uris AS "redirectUris",
             created_at AS "createdAt"
      FROM social_bridge_oauth_clients
      WHERE client_id = $1
    `, [String(clientId)]);
    return result.rows[0] || null;
  }

  async saveOAuthCode(code) {
    await this.pool.query(`
      INSERT INTO social_bridge_oauth_codes
        (code_hash, client_id, redirect_uri, code_challenge, scopes, resource, expires_at, consumed)
      VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, FALSE)
    `, [code.codeHash, code.clientId, code.redirectUri, code.codeChallenge, JSON.stringify(code.scopes), code.resource, code.expiresAt]);
  }

  async consumeOAuthCode(codeHash) {
    const result = await this.pool.query(`
      UPDATE social_bridge_oauth_codes
      SET consumed = TRUE
      WHERE code_hash = $1 AND consumed = FALSE
      RETURNING client_id AS "clientId", redirect_uri AS "redirectUri",
                code_challenge AS "codeChallenge", scopes, resource,
                expires_at AS "expiresAt"
    `, [String(codeHash)]);
    return result.rows[0] || null;
  }

  async saveOAuthToken(token) {
    await this.pool.query(`
      INSERT INTO social_bridge_oauth_tokens
        (token_hash, refresh_hash, client_id, scopes, resource, access_expires_at, refresh_expires_at, revoked)
      VALUES ($1, $2, $3, $4::jsonb, $5, $6, $7, FALSE)
    `, [
      token.tokenHash,
      token.refreshHash,
      token.clientId,
      JSON.stringify(token.scopes),
      token.resource,
      token.accessExpiresAt,
      token.refreshExpiresAt
    ]);
  }

  async getOAuthTokenByAccessHash(accessHash) {
    const result = await this.pool.query(`
      SELECT token_hash AS "tokenHash", refresh_hash AS "refreshHash", client_id AS "clientId",
             scopes, resource, access_expires_at AS "accessExpiresAt",
             refresh_expires_at AS "refreshExpiresAt"
      FROM social_bridge_oauth_tokens
      WHERE token_hash = $1 AND revoked = FALSE
    `, [String(accessHash)]);
    return result.rows[0] || null;
  }

  async getOAuthTokenByRefreshHash(refreshHash) {
    const result = await this.pool.query(`
      SELECT token_hash AS "tokenHash", refresh_hash AS "refreshHash", client_id AS "clientId",
             scopes, resource, access_expires_at AS "accessExpiresAt",
             refresh_expires_at AS "refreshExpiresAt"
      FROM social_bridge_oauth_tokens
      WHERE refresh_hash = $1 AND revoked = FALSE
    `, [String(refreshHash)]);
    return result.rows[0] || null;
  }

  async revokeOAuthToken(accessHash) {
    await this.pool.query(`
      UPDATE social_bridge_oauth_tokens SET revoked = TRUE WHERE token_hash = $1
    `, [String(accessHash)]);
  }
}

export async function createStore() {
  const store = process.env.DATABASE_URL
    ? new PostgresStore(process.env.DATABASE_URL)
    : new MemoryStore();
  await store.init();
  return store;
}
