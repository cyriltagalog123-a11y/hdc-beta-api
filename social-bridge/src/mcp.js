import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';
import { publishTextPost, listRecentPosts } from './meta.js';

function text(data) {
  return { content: [{ type: 'text', text: typeof data === 'string' ? data : JSON.stringify(data, null, 2) }] };
}

function buildServer(store) {
  const server = new McpServer({
    name: 'hdc-social-bridge',
    version: '0.1.0'
  });

  server.tool(
    'list_connected_pages',
    'List Facebook Pages currently connected to HDC Social Bridge. This is read-only.',
    {},
    async () => text(await store.listPages())
  );

  server.tool(
    'list_recent_posts',
    'List recent published posts for a connected Facebook Page. This is read-only.',
    {
      pageId: z.string().min(1),
      limit: z.number().int().min(1).max(25).optional()
    },
    async ({ pageId, limit }) => {
      const page = await store.getPage(pageId);
      if (!page) throw new Error('Page is not connected');
      const posts = await listRecentPosts(page.pageId, page.accessToken, limit || 10);
      return text(posts);
    }
  );

  server.tool(
    'publish_text_post',
    'Publish a text post to a connected Facebook Page. Only call after the user has explicitly approved publishing this exact post. Set confirm=true only after that approval.',
    {
      pageId: z.string().min(1),
      message: z.string().min(1).max(63206),
      confirm: z.boolean()
    },
    async ({ pageId, message, confirm }) => {
      if (confirm !== true) {
        return { isError: true, ...text('Publishing blocked: explicit confirmation is required.') };
      }

      const page = await store.getPage(pageId);
      if (!page) throw new Error('Page is not connected');

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
        throw error;
      }
    }
  );

  return server;
}

export async function handleMcpRequest(req, res, store) {
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
    enableJsonResponse: true
  });
  const server = buildServer(store);
  res.on('close', () => {
    transport.close().catch(() => {});
    server.close().catch(() => {});
  });
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
}
