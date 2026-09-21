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
import {
  authenticateBearer,
  authorizeGet,
  authorizePost,
  mcpResource,
  oauthMetadata,
  protectedResourceMetadata,
  publicBaseUrl,
  registerClient,
  tokenEndpoint
} from './oauth.js';

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

function deploymentWarning() {
  if (!process.env.DATABASE_URL) {
    return 'DATABASE_URL is not configured. Connections are currently stored only in memory and will disappear on restart. This mode is for local testing only.';
  }
  return '';
}

function page(title, body) {
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><style>body{font-family:system-ui;max-width:820px;margin:48px auto;padding:0 20px;line-height:1.6;color:#102035}a{color:#1268c4}h1,h2{line-height:1.2}</style></head><body>${body}</body></html>`;
}

export async function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.urlencoded({ extended: false, limit: '256kb' }));
  app.use(express.json({ limit: '256kb' }));

  const store = await createStore();
  const base = publicBaseUrl();

  app.get('/health', (_req, res) => {
    res.json({ ok: true, service: 'hdc-social-bridge', version: '0.2.0', mcp: `${base}/mcp` });
  });

  app.get('/', (_req, res) => {
    res.type('html').send(page('HDC Social Bridge', `
      <h1>HDC Social Bridge</h1>
      <p>Secure connector between ChatGPT and the HelpDesk Connect Facebook Page.</p>
      <p><a href="/privacy">Privacy</a> · <a href="/terms">Terms</a> · <a href="/support">Support</a> · <a href="/docs/mcp">MCP documentation</a></p>
    `));
  });

  app.get('/privacy', (_req, res) => {
    res.type('html').send(page('Privacy Policy — HDC Social Bridge', `
      <h1>Privacy Policy</h1>
      <p>HDC Social Bridge stores only the data needed to connect and operate the HelpDesk Connect Facebook Page: encrypted Facebook Page access tokens, Page identifiers and names, granted Page tasks, OAuth connection records, and an audit history of Social Bridge actions.</p>
      <p>Facebook passwords are never collected or stored. ChatGPT/OAuth access tokens are stored only as one-way hashes. Facebook Page tokens are encrypted at rest.</p>
      <p>Tool responses exclude authentication secrets. Data is used only to provide Page connection, read-back, and explicitly approved publishing functions.</p>
      <p>For access, correction, or deletion requests, use the <a href="/support">support page</a>.</p>
    `));
  });

  app.get('/terms', (_req, res) => {
    res.type('html').send(page('Terms — HDC Social Bridge', `
      <h1>Terms of Use</h1>
      <p>HDC Social Bridge is provided to manage authorized HelpDesk Connect social publishing workflows. Users must have authority over any connected Facebook Page and must comply with Meta and OpenAI platform rules.</p>
      <p>Publishing requires explicit approval of the exact post text. The service must not be used to publish unlawful, deceptive, abusive, or unauthorized content.</p>
      <p>Availability may depend on Meta, OpenAI, Railway, database, and network services outside HDC Social Bridge control.</p>
    `));
  });

  app.get('/support', (_req, res) => {
    res.type('html').send(page('Support — HDC Social Bridge', `
      <h1>Support</h1>
      <p>For HDC Social Bridge support, use the HelpDesk Connect owner/admin support channel associated with this deployment.</p>
      <p>When reporting an issue, include the approximate time and action attempted. Never include Facebook access tokens, OAuth tokens, passwords, or application secrets.</p>
    `));
  });

  app.get('/docs/mcp', (_req, res) => {
    res.type('html').send(page('MCP — HDC Social Bridge', `
      <h1>HDC Social Bridge MCP</h1>
      <p>Production MCP endpoint: <code>${mcpResource()}</code></p>
      <h2>Scopes</h2>
      <p><code>social.read</code> lists connected Pages and recent posts. <code>social.publish</code> publishes an explicitly approved text post.</p>
      <h2>Safety</h2>
      <p>The publish tool requires both the <code>social.publish</code> OAuth scope and an explicit <code>confirm=true</code> argument after the user approves the exact text.</p>
    `));
  });

  app.get('/.well-known/oauth-protected-resource', (_req, res) => res.json(protectedResourceMetadata()));
  app.get('/.well-known/oauth-authorization-server', (_req, res) => res.json(oauthMetadata()));

  app.get('/.well-known/openai-apps-challenge', (_req, res) => {
    const token = process.env.OPENAI_APPS_CHALLENGE;
    if (!token) return res.status(404).type('text').send('Not configured');
    res.type('text/plain').send(token);
  });

  app.post('/oauth/register', (req, res) => registerClient(req, res, store));
  app.get('/oauth/authorize', (req, res) => authorizeGet(req, res, store));
  app.post('/oauth/authorize', (req, res) => authorizePost(req, res, store));
  app.post('/oauth/token', (req, res) => tokenEndpoint(req, res, store));

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
      for (const fbPage of pages) await store.savePage(fbPage);
      await store.addAudit({
        action: 'facebook_connect',
        payload: { pageCount: pages.length, pageNames: pages.map((item) => item.name) },
        success: true,
        result: { pageIds: pages.map((item) => item.id) }
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
    const fbPage = await store.getPage(req.body.pageId);
    const message = String(req.body.message || '').trim();
    if (!fbPage || !message) return res.status(400).send('Page and message are required');

    try {
      const result = await publishTextPost(fbPage.pageId, fbPage.accessToken, message);
      await store.addAudit({ action: 'admin_publish_text', pageId: fbPage.pageId, payload: { message }, success: true, result });
      res.redirect('/admin');
    } catch (error) {
      await store.addAudit({ action: 'admin_publish_text', pageId: fbPage.pageId, payload: { message }, success: false, result: { error: error.message, meta: error.meta || null } });
      res.redirect(`/admin?error=${encodeURIComponent(error.message)}`);
    }
  });

  app.post('/mcp', async (req, res) => {
    try {
      const auth = await authenticateBearer(req, store);
      await handleMcpRequest(req, res, store, auth);
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.status(500).json({ error: 'MCP request failed' });
    }
  });

  app.get('/mcp', (_req, res) => {
    res.status(405).json({ error: 'Use MCP Streamable HTTP POST requests.' });
  });

  app.use((error, _req, res, _next) => {
    console.error(error);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}
