import { describe, expect, it } from 'vitest';
import {
  corsPreflightResponse,
  isWebOriginAllowed,
  withCors,
} from '../netlify/functions/_lib/cors.mjs';

describe('HDC Flutter web origin policy', () => {
  it('allows the exact configured hosted origin', () => {
    expect(isWebOriginAllowed(
      'https://api.hdc.test/api/auth/login',
      'https://app.hdc.test',
      ['https://app.hdc.test'],
    )).toBe(true);
  });

  it('allows local Flutter Chrome without opening arbitrary web origins', () => {
    expect(isWebOriginAllowed(
      'https://api.hdc.test/api/auth/login',
      'http://localhost:53421',
      [],
    )).toBe(true);
    expect(isWebOriginAllowed(
      'https://api.hdc.test/api/auth/login',
      'https://untrusted.example',
      [],
    )).toBe(false);
    expect(isWebOriginAllowed(
      'https://api.hdc.test/api/auth/login',
      'https://app.hdc.test',
      ['*', 'https://app.hdc.test/path'],
    )).toBe(false);
    expect(isWebOriginAllowed(
      'https://api.hdc.test/api/auth/login',
      'http://app.hdc.test',
      ['http://app.hdc.test'],
    )).toBe(false);
  });

  it('answers allowed preflight and attaches origin-specific headers', () => {
    const request = new Request('https://api.hdc.test/api/auth/login', {
      method: 'OPTIONS',
      headers: { origin: 'https://app.hdc.test' },
    });
    const preflight = corsPreflightResponse(request, ['https://app.hdc.test']);
    expect(preflight.status).toBe(204);
    expect(preflight.headers.get('access-control-allow-origin'))
      .toBe('https://app.hdc.test');

    const response = withCors(
      new Request('https://api.hdc.test/api/health', {
        headers: { origin: 'https://app.hdc.test' },
      }),
      new Response('{}', { status: 200 }),
      ['https://app.hdc.test'],
    );
    expect(response.headers.get('access-control-allow-origin'))
      .toBe('https://app.hdc.test');
  });

  it('rejects preflight from an unconfigured hosted origin', () => {
    const response = corsPreflightResponse(
      new Request('https://api.hdc.test/api/auth/login', {
        method: 'OPTIONS',
        headers: { origin: 'https://untrusted.example' },
      }),
      [],
    );
    expect(response.status).toBe(403);
    expect(response.headers.has('access-control-allow-origin')).toBe(false);
  });
});
