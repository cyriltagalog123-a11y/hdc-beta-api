import { describe, expect, it } from 'vitest';
import { databaseUrlForRequest } from '../netlify/functions/_lib/deploy-database.mjs';

const hosted = {
  SITE_ID: '04dc4526-8ac3-461b-9488-58f7825ce6fa',
  SITE_NAME: 'hdc-beta-api',
  URL: 'https://hdc-beta-api.netlify.app',
  HDC_DATABASE_URL: 'postgres://production.example/hdc',
};

function select(url: string | undefined, values: Record<string, string>): string {
  return databaseUrlForRequest(url, (name) => values[name]);
}

describe('hosted database isolation', () => {
  it('uses production only at the configured primary origin', () => {
    expect(select('https://hdc-beta-api.netlify.app/api/commerce/catalog', hosted))
      .toBe(hosted.HDC_DATABASE_URL);
    expect(select('https://hdc.example/api/health/ready', {
      ...hosted,
      URL: 'https://hdc.example',
    })).toBe(hosted.HDC_DATABASE_URL);
  });

  it('requires a distinct database for deploy previews and branch deploys', () => {
    const isolated = {
      ...hosted,
      HDC_PREVIEW_DATABASE_URL: 'postgres://preview.example/hdc_preview',
    };
    expect(select('https://deploy-preview-42--hdc-beta-api.netlify.app/api/news', isolated))
      .toBe(isolated.HDC_PREVIEW_DATABASE_URL);
    expect(select('https://review-shop--hdc-beta-api.netlify.app/api/community', isolated))
      .toBe(isolated.HDC_PREVIEW_DATABASE_URL);
    expect(select('https://deploy-preview-42--hdc-beta-api.netlify.app/api/news', {
      ...isolated,
      HDC_DATABASE_URL: '',
    })).toBe(isolated.HDC_PREVIEW_DATABASE_URL);
    for (const configuration of [hosted, {
      ...isolated,
      HDC_PREVIEW_DATABASE_URL: hosted.HDC_DATABASE_URL,
    }]) {
      expect(() => select(
        'https://deploy-preview-42--hdc-beta-api.netlify.app/api/auth/login', configuration,
      )).toThrow(/distinct isolated database URL/);
    }
  });

  it('fails closed on incomplete metadata or an unrecognized deploy origin', () => {
    for (const url of [
      'https://other.netlify.app/api/commerce/catalog',
      'https://deploy-preview-42--another-site.netlify.app/api/commerce/catalog',
      'http://deploy-preview-42--hdc-beta-api.netlify.app/api/commerce/catalog',
      'https://-invalid--hdc-beta-api.netlify.app/api/commerce/catalog',
    ]) {
      expect(() => select(url, hosted)).toThrow();
    }
    expect(() => select(undefined, hosted)).toThrow(/context is incomplete/);
    expect(() => select('https://hdc-beta-api.netlify.app/api/news', {
      ...hosted,
      SITE_ID: '',
    })).toThrow(/context is incomplete/);
  });

  it('continues to use the configured test database outside Netlify', () => {
    expect(select('http://localhost:8888/api/health/ready', {
      HDC_DATABASE_URL: 'postgres://localhost/hdc_test',
    })).toBe('postgres://localhost/hdc_test');
  });
});
