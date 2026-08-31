import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { handleHdcApiRequest } from '../netlify/functions/api.mjs';

const expectedDocuments = {
  terms_of_service: {
    path: '../legal/terms-of-service-beta-2026-08-29.txt',
    publicPath: '/legal/terms/',
  },
  privacy_notice: {
    path: '../legal/privacy-notice-beta-2026-08-29.txt',
    publicPath: '/legal/privacy/',
  },
} as const;

describe('published HDC legal documents', () => {
  it('serves the current version and exact canonical content hashes', async () => {
    const response = await handleHdcApiRequest(
      new Request('https://hdc.test/api/legal/documents'),
    );

    expect(response.status).toBe(200);
    const body = await response.json() as {
      version: string;
      documents: Array<{
        documentType: keyof typeof expectedDocuments;
        version: string;
        contentSha256: string;
        publicPath: string;
      }>;
    };
    expect(body.version).toBe('beta-2026-08-29');
    expect(body.documents).toHaveLength(2);

    for (const document of body.documents) {
      const expected = expectedDocuments[document.documentType];
      expect(expected).toBeDefined();
      const canonical = readFileSync(
        fileURLToPath(new URL(expected.path, import.meta.url)),
      );
      expect(document.version).toBe(body.version);
      expect(document.publicPath).toBe(expected.publicPath);
      expect(document.contentSha256).toBe(
        createHash('sha256').update(canonical).digest('hex'),
      );
    }
  });
});
