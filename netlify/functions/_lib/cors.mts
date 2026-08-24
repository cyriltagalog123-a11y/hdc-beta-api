import { webAllowedOrigins } from './env.mjs';

const allowedMethods = 'GET, POST, PUT, DELETE, OPTIONS';
const allowedHeaders = 'Authorization, Content-Type, Accept';

function normalizedOrigin(value: string): string | null {
  try {
    const uri = new URL(value);
    if (uri.protocol !== 'https:' && uri.protocol !== 'http:') return null;
    return uri.origin;
  } catch {
    return null;
  }
}

function isLoopbackOrigin(value: string): boolean {
  try {
    const uri = new URL(value);
    return (uri.protocol === 'http:' || uri.protocol === 'https:') &&
      (uri.hostname === 'localhost' ||
        uri.hostname === '127.0.0.1' ||
        uri.hostname === '[::1]' ||
        uri.hostname === '::1');
  } catch {
    return false;
  }
}

export function isWebOriginAllowed(
  requestUrl: string,
  origin: string,
  configuredOrigins: readonly string[] = webAllowedOrigins(),
): boolean {
  const normalized = normalizedOrigin(origin);
  if (!normalized || normalized !== origin || origin === 'null') return false;
  if (normalized === new URL(requestUrl).origin) return true;

  // Flutter's local Chrome runner uses a loopback origin with a random port.
  // This exception is narrow: it never permits LAN addresses or arbitrary
  // HTTP origins. Hosted web clients must be explicitly configured below.
  if (isLoopbackOrigin(normalized)) return true;

  return configuredOrigins.some((item) => {
    const allowed = normalizedOrigin(item);
    return allowed !== null &&
      new URL(allowed).protocol === 'https:' &&
      allowed === item &&
      allowed === normalized;
  });
}

function corsHeaders(origin: string): Headers {
  return new Headers({
    'access-control-allow-origin': origin,
    'access-control-allow-methods': allowedMethods,
    'access-control-allow-headers': allowedHeaders,
    'access-control-max-age': '600',
    'vary': 'Origin, Access-Control-Request-Method, Access-Control-Request-Headers',
  });
}

export function corsPreflightResponse(
  req: Request,
  configuredOrigins: readonly string[] = webAllowedOrigins(),
): Response {
  const origin = req.headers.get('origin') ?? '';
  if (!isWebOriginAllowed(req.url, origin, configuredOrigins)) {
    return new Response(null, {
      status: 403,
      headers: { vary: 'Origin' },
    });
  }
  return new Response(null, { status: 204, headers: corsHeaders(origin) });
}

export function withCors(
  req: Request,
  response: Response,
  configuredOrigins: readonly string[] = webAllowedOrigins(),
): Response {
  const origin = req.headers.get('origin') ?? '';
  if (!isWebOriginAllowed(req.url, origin, configuredOrigins)) return response;
  const headers = new Headers(response.headers);
  corsHeaders(origin).forEach((value, name) => headers.set(name, value));
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
