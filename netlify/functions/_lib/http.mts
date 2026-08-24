export function json(
  body: unknown,
  status = 200,
  extraHeaders: HeadersInit = {},
): Response {
  const headers = new Headers(extraHeaders);
  headers.set('content-type', 'application/json; charset=utf-8');
  headers.set('cache-control', 'no-store');
  headers.set('content-security-policy', "default-src 'none'; frame-ancestors 'none'");
  headers.set('referrer-policy', 'no-referrer');
  headers.set('x-content-type-options', 'nosniff');
  headers.set('x-frame-options', 'DENY');
  return new Response(JSON.stringify(body), {
    status,
    headers,
  });
}

export function methodNotAllowed(): Response {
  return json({ error: 'method_not_allowed' }, 405);
}

export async function readJson(req: Request): Promise<Record<string, unknown> | null> {
  try {
    const value = await req.json();
    return value && typeof value === 'object' && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

export function bearerToken(req: Request): string | null {
  const header = req.headers.get('authorization') ?? '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  return match?.[1]?.trim() || null;
}
