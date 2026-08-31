import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const read = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

describe('Flutter web startup recovery', () => {
  it('renders a visible Build 24 loading state before Flutter starts', () => {
    const index = read('web/index.html');

    expect(index).toContain('id="hdc-startup"');
    expect(index).toContain('Build 24');
    expect(index).toContain('Opening your secure workspace');
    expect(index).toContain('src="hdc_startup.js"');
    expect(index.indexOf('src="hdc_startup.js"')).toBeLessThan(
      index.indexOf('src="flutter_bootstrap.js"'),
    );
  });

  it('offers bounded recovery without deleting account or server data', () => {
    const startup = read('web/hdc_startup.js');

    expect(startup).toContain("'flutter-first-frame'");
    expect(startup).toContain('15000');
    expect(startup).toContain('registration.unregister()');
    expect(startup).toContain('caches.delete(cacheName)');
    expect(startup).toContain("searchParams.set('hdc_refresh'");
    expect(startup).not.toContain('localStorage.clear');
    expect(startup).not.toContain('indexedDB.deleteDatabase');
  });

  it('prevents the entry files from being stored by browsers', () => {
    const netlify = read('netlify.toml');

    for (const path of [
      '/',
      '/index.html',
      '/flutter_bootstrap.js',
      '/flutter_service_worker.js',
      '/hdc_startup.js',
      '/legal/*',
    ]) {
      expect(netlify).toContain(`for = "${path}"`);
    }

    expect(netlify.match(/no-cache, no-store, must-revalidate/g)).toHaveLength(7);
  });

  it('fails the production build if the recovery shell is omitted', () => {
    const preparation = read('scripts/prepare-netlify-web.mjs');

    expect(preparation).toContain('id="hdc-startup"');
    expect(preparation).toContain('src="hdc_startup.js"');
    expect(preparation).toContain("new URL('hdc_startup.css', buildDirectory)");
    expect(preparation).toContain("new URL('hdc_startup.js', buildDirectory)");
  });
});
