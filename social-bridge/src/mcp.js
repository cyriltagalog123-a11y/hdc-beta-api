import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';
import { publishTextPost, listRecentPosts } from './meta.js';
import { authChallenge } from './oauth.js';

function text(data) {
  return { content: [{ type: 'text', text: typeof data === 'string' ? data : JSON.stringify(data, null, 2) }] };
}

function authRequired(scope) {
  return {
    isError: true,
    ...text('Authentication required. Connect HDC Social Bridge to continue.'),
    _meta: {
      'mcp/www_authenticate': [authChallenge(scope)]
    }
  };
}

function hasScope(auth, scope) {
  return Boolean(auth?.scopes?.includes(scope));
}

function buildServer(store, auth) {
  const server = new McpServer(
    { name: 'hdc-social-bridge', version: '0.2.0' },
    {
      instructions: 'Use read tools freely after authentication. Publish only when the user has explicitly approved the exact Facebook Page post text in the current conversation. Never set confirm=true based on implied approval.'
    }
  );

  server.registerTool(
    'get_account_profile',
    {
      title: 'HDC Social Bridge account',
      description: 'Identify the connected HDC Social Bridge account for account-selection and connection status. Read-only.',
      inputSchema: z.object({}),
      securitySchemes: [{ type: 'oauth2', scopes: ['social.read'] }],
      annotations: { readOnlyHint: true, openWorldHint: false },
      _meta: { 'openai/profile': true }
    },
    async () => {
      if (!hasScope(auth, 'social.read')) return authRequired('social.read');
      const pages = await store.listPages();
      return text({
        account_id: 'hdc-social-bridge-owner',
        account_name: 'HDC Social Bridge',
        connected_pages: pages.map((page) => ({ id: page.pageId, name: page.pageName }))
      });
    }
  );

  server.registerTool(
    'list_connected_pages',
    {
      title: 'List connected Facebook Pages',
      description: 'List Facebook Pages currently connected to HDC Social Bridge. Read-only.',
      inputSchema: z.object({}),
      securitySchemes: [{ type: 'oauth2', scopes: ['social.read'] }],
      annotations: { readOnlyHint: true, openWorldHint: false }
    },
    async () => {
      if (!hasScope(auth, 'social.read')) return authRequired('social.read');
      return text(await store.listPages());
    }
  );

  server.registerTool(
    'list_recent_posts',
    {
      title: 'List recent Facebook Page posts',
      description: 'List recent posts from one Facebook Page connected to HDC Social Bridge. Read-only.',
      inputSchema: z.object({
        pageId: z.string().min(1),
        limit: z.number().int().min(1).max(25).optional()
      }),
      securitySchemes: [{ type: 'oauth2', scopes: ['social.read'] }],
      annotations: { readOnlyHint: true, openWorldHint: false }
    },
    async ({ pageId, limit }) => {
      if (!hasScope(auth, 'social.read')) return authRequired('social.read');
      const page = await store.getPage(pageId);
      if (!page) return { isError: true, ...text('Page is not connected.') };
      const posts = await listRecentPosts(page.pageId, page.accessToken, limit || 10);
      return text(posts);
    }
  );

  server.registerTool(
    'publish_text_post',
    {
      title: 'Publish Facebook Page text post',
      description: 'Publish a text post to a connected Facebook Page. Use only after the user explicitly approves the exact post text. confirm must be true only after that approval.',
      inputSchema: z.object({
        pageId: z.string().min(1),
        message: z.string().min(1).max(63206),
        confirm: z.boolean()
      }),
      securitySchemes: [{ type: 'oauth2', scopes: ['social.publish'] }],
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false
      }
    },
    async ({ pageId, message, confirm }) => {
      if (!hasScope(auth, 'social.publish')) return authRequired('social.publish');
      if (confirm !== true) {
        return { isError: true, ...text('Publishing blocked: explicit confirmation is required.') };
      }

      const page = await store.getPage(pageId);
      if (!page) return { isError: true, ...text('Page is not connected.') };

      try {
        const result = await publishTextPost(page.pageId, page.accessToken, message);
        await store.addAudit({
          action: 'publish_text_post',
          pageId: page.pageId,
          payload: { message },
          success: true,
          result
        });
        return text({ success: true, page: page.pageName, ...result });
      } catch (error) {
        await store.addAudit({
          action: 'publish_text_post',
          pageId: page.pageId,
          payload: { message },
          success: false,
          result: { error: error.message, meta: error.meta || null }
        });
        return { isError: true, ...text(`Facebook publishing failed: ${error.message}`) };
      }
    }
  );

  return server;
}

export async function handleMcpRequest(req, res, store, auth) {
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
    enableJsonResponse: true
  });
  const server = buildServer(store, auth);
  res.on('close', () => {
    transport.close().catch(() => {});
    server.close().catch(() => {});
  });
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
}
