import type { IncomingMessage, ServerResponse } from 'node:http';
import { Readable } from 'node:stream';

export type HdcWebRequestHandler = (request: Request) => Promise<Response>;

export type NodeHttpAdapterOptions = Readonly<{
  publicOrigin: string;
}>;

/**
 * Wraps the HDC Web handler for ordinary Node HTTP servers and containers.
 * The adapter owns transport conversion only; authorization and domain behavior
 * remain inside handleHdcApiRequest.
 */
export function createNodeHttpAdapter(
  handler: HdcWebRequestHandler,
  options: NodeHttpAdapterOptions,
): (request: IncomingMessage, response: ServerResponse) => Promise<void> {
  const origin = new URL(options.publicOrigin);
  if (origin.protocol !== 'https:' && origin.hostname !== 'localhost') {
    throw new Error('The public HDC origin must use HTTPS outside localhost.');
  }

  return async (incoming, outgoing) => {
    try {
      const url = new URL(incoming.url ?? '/', origin);
      const method = incoming.method ?? 'GET';
      const headers = new Headers();
      for (const [name, value] of Object.entries(incoming.headers)) {
        if (Array.isArray(value)) {
          for (const item of value) headers.append(name, item);
        } else if (value !== undefined) {
          headers.set(name, value);
        }
      }

      const init: RequestInit & { duplex?: 'half' } = { method, headers };
      if (method !== 'GET' && method !== 'HEAD') {
        init.body = Readable.toWeb(incoming) as ReadableStream<Uint8Array>;
        init.duplex = 'half';
      }
      const result = await handler(new Request(url, init));

      outgoing.statusCode = result.status;
      result.headers.forEach((value, name) => outgoing.setHeader(name, value));
      if (!result.body) {
        outgoing.end();
        return;
      }
      outgoing.end(Buffer.from(await result.arrayBuffer()));
    } catch {
      if (!outgoing.headersSent) {
        outgoing.statusCode = 500;
        outgoing.setHeader('content-type', 'application/json; charset=utf-8');
      }
      outgoing.end('{"error":"internal_error"}');
    }
  };
}
