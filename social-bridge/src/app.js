import express from 'express';
import { createStore } from './store.js';
import { createOAuthState, verifyOAuthState, secureEqual } from './security.js';
import {
  buildFacebookLoginUrl,
  exchangeCode,
  exchangeForLongLivedUserToken,
  listManagedPages,
  publishTextPost
} from './meta.js';
import { renderAdmin, renderCallbackSuccess } from './ui.js';
import { handleMcpRequest } from './mcp.js';

function basicAdmin(req, res, next) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Basic ')) {
    res.setHeader('WWW-Authenticate', 'Basic realm="HDC Social Bridge"');
    return res.status(401).send('Authentication required');
  }
  try {
    const [username, password] = Buffer.from(header.slice(6), 'base64').toString('utf8').split(':');
    if (!secureEqual(username, process.env.ADMIN_USERNAME) || !secureEqual(password, process.env.ADMIN_PASSWORD)) {
      res.setHeader('WWW-Authenticate', 'Basic realm="HDC Social Bridge"');
      return res.status(401).send('Invalid credentials');
    }
    next();
  } catch {
    return res.status(401).send('Invalid credentials');
  }
}

function mcpAuth(req, res, next) {
  const expected = process.env.SOCIAL_BRIDGE_API_KEY;
  const provided = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!expected || !secureEqual(provided, expected)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

function deploymentWarning() {
  if (!process.env.DATABASE_URL) {
    return 'DATABASE_URL is not configured. Connections are currently stored only in memory and will disappear on restart. This mode is for local testing only.';
  }
  return '';
}

export async function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.urlencoded({ extended: false, limit: '256kb' }));
  app.use(express.json({ limit: '256kb' }));

  const store = await createStore();

  app.get('/health', (_req, res) => {
    res.json({ ok: true, service: 'hdc-social-bridge', version: '0.1.0' });
  });

  app.get('/', (_req, res) => res.redirect('/admin'));

  app.get('/admin', basicAdmin, async (req, res) => {
    const [pages, audit] = await Promise.all([store.listPages(), store.listAudit(25)]);
    res.type('html').send(renderAdmin({
      pages,
      audit,
      warning: deploymentWarning(),
      error: req.query.error || ''
    }));
  });

  app.get('/auth/facebook', basicAdmin, (_req, res) => {
    res.redirect(buildFacebookLoginUrl(createOAuthState()));
  });

  app.get('/auth/facebook/callback', async (req, res) => {
    if (req.query.error) {
      return res.status(400).send(`Facebook authorization failed: ${String(req.query.error_description || req.query.error)}`);
    }
    if (!verifyOAuthState(req.query.state)) {
      return res.status(400).send('Invalid or expired OAuth state');
    }
    if (!req.query.code) return res.status(400).send('Missing OAuth code');

    try {
      const shortToken = await exchangeCode(String(req.query.code));
      const userToken = await exchangeForLongLivedUserToken(shortToken);
      const pages = await listManagedPages(userToken);
      for (const page of pages) await store.savePage(page);
      await store.addAudit({
        action: 'facebook_connect',
        payload: { pageCount: pages.length, pageNames: pages.map((p) => p.name) },
        success: true,
        result: { pageIds: pages.map((p) => p.id) }
      });
      res.type('html').send(renderCallbackSuccess(pages));
    } catch (error) {
      await store.addAudit({
        action: 'facebook_connect',
        payload: {},
        success: false,
        result: { error: error.message, meta: error.meta || null }
      });
      res.status(500).send(`Facebook connection failed: ${error.message}`);
    }
  });

  app.post('/admin/publish', basicAdmin, async (req, res) => {
    const page = await store.getPage(req.body.pageId);
    const message = String(req.body.message || '').trim();
    if (!page || !message) return res.status(400).send('Page and message are required');

    try {
      const result = await publishTextPost(page.pageId, page.accessToken, message);
      await store.addAudit({ action: 'admin_publish_text', pageId: page.pageId, payload: { message }, success: true, result });
      res.redirect('/admin');
    } catch (error) {
      await store.addAudit({ action: 'admin_publish_text', pageId: page.pageId, payload: { message }, success: false, result: { error: error.message, meta: error.meta || null } });
      res.redirect(`/admin?error=${encodeURIComponent(error.message)}`);
    }
  });

  app.post('/mcp', mcpAuth, async (req, res) => {
    try {
      await handleMcpRequest(req, res, store);
    } catch (error) {
      if (!res.headersSent) res.status(500).json({ error: error.message });
    }
  });

  app.get('/mcp', mcpAuth, (_req, res) => res.status(405).json({ error: 'Use MCP Streamable HTTP POST requests.' }));

  app.use((error, _req, res, _next) => {
    console.error(error);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}
