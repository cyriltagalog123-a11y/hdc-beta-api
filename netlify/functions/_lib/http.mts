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

export const DEFAULT_MAX_JSON_REQUEST_BYTES = 64 * 1024;

export async function readJson(
  req: Request,
  maxBytes = DEFAULT_MAX_JSON_REQUEST_BYTES,
): Promise<Record<string, unknown> | null> {
  const contentLength = req.headers.get('content-length');
  if (contentLength) {
    const declared = Number(contentLength);
    if (Number.isFinite(declared) && declared > maxBytes) return null;
  }

  try {
    const reader = req.body?.getReader();
    if (!reader) return null;
    const decoder = new TextDecoder();
    let received = 0;
    let text = '';
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      received += value.byteLength;
      if (received > maxBytes) {
        await reader.cancel();
        return null;
      }
      text += decoder.decode(value, { stream: true });
    }
    text += decoder.decode();
    const value = JSON.parse(text);
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
