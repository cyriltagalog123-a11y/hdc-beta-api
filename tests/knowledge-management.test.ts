import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({ sql: vi.fn(), authorize: vi.fn(), close: vi.fn() }));
vi.mock('../netlify/functions/_lib/db.mjs', () => ({
  openDb: () => mocks.sql, closeDb: mocks.close,
}));
vi.mock('../netlify/functions/_lib/internal-auth.mjs', () => ({
  authorizeInternalRequest: mocks.authorize,
}));

import handler from '../netlify/functions/knowledge-admin.mjs';

const row = (id: string) => ({
  id, public_article_id: `KB-${id}`, slug: `guide-${id}`, category: 'pc_laptop',
  title: `Guide ${id}`, summary: 'A helpful guide.', body: 'Guide context.',
  steps: ['First step'], tags: ['laptop'], safety_level: 'low',
  status: 'draft', version: 1, ever_published: false,
});
const request = (query = '') => new Request(`https://hdc.test/api/internal/knowledge${query}`);

describe('Knowledge management search', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.authorize.mockResolvedValue({ userId: 'writer', internalRoles: ['admin'] });
    mocks.sql.mockResolvedValue([]);
  });

  it('requires internal authorization before reading any guides', async () => {
    mocks.authorize.mockResolvedValue(new Response('{}', { status: 403 }));
    expect((await handler(request('?q=private'))).status).toBe(403);
    expect(mocks.sql).not.toHaveBeenCalled();
    expect(mocks.close).toHaveBeenCalledOnce();
  });

  it('returns a lookahead cursor without leaking the extra row', async () => {
    mocks.sql.mockResolvedValue([row('a'), row('b'), row('c')]);
    const response = await handler(request('?limit=2&offset=300'));
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body.articles.map((article: { id: string }) => article.id)).toEqual(['a', 'b']);
    expect(body.hasMore).toBe(true);
    expect(body.nextOffset).toBe(302);
    expect(body.canPublish).toBe(false);
    expect(mocks.sql.mock.calls[0].slice(-2)).toEqual([3, 300]);
  });

  it('stops pagination on the last page and preserves publisher capability', async () => {
    mocks.authorize.mockResolvedValue({ userId: 'owner', internalRoles: ['owner'] });
    mocks.sql.mockResolvedValue([row('last')]);
    const body = await (await handler(request('?limit=2&offset=302'))).json();
    expect(body.articles).toHaveLength(1);
    expect(body.hasMore).toBe(false);
    expect(body.nextOffset).toBeNull();
    expect(body.canPublish).toBe(true);
  });

  it('binds search, category, and status as values, including SQL-like search text', async () => {
    const query = "50%_USB' OR true --";
    await handler(request(`?q=${encodeURIComponent(query)}&category=pc_laptop&status=review`));
    const [template, ...values] = mocks.sql.mock.calls[0];
    expect(values).toContain(query.toLowerCase());
    expect(values).toContain('pc_laptop');
    expect(values).toContain('review');
    expect(template.join('')).not.toContain(query);
  });

  it.each([
    '?offset=-1', '?offset=1.5', '?offset=1000001', '?offset=abc',
    '?limit=0', '?limit=101', '?limit=Infinity', '?limit=',
    '?category=unknown', '?status=deleted',
  ])('rejects malformed filters without querying the database: %s', async (query) => {
    const response = await handler(request(query));
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: 'invalid_knowledge_filters' });
    expect(mocks.sql).not.toHaveBeenCalled();
  });
});
