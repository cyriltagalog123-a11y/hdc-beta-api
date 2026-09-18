import pg from 'pg';
import { encryptToken, decryptToken } from './security.js';

const { Pool } = pg;

class MemoryStore {
  constructor() {
    this.pages = new Map();
    this.audit = [];
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
}

export async function createStore() {
  const store = process.env.DATABASE_URL
    ? new PostgresStore(process.env.DATABASE_URL)
    : new MemoryStore();
  await store.init();
  return store;
}
