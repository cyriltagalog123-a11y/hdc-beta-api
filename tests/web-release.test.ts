import { describe, expect, it } from 'vitest';
import { prepareWebRelease } from '../scripts/lib/web-release.mjs';

const input = {
  bootstrap: '_flutter.loader.load({serviceWorkerVersion: "generated"});',
  worker: 'const RESOURCES = {"main.dart.js":"first"};',
  entrypoint: 'console.log("first patch");',
  version: '0.6.4-build.27',
  revision: 'a'.repeat(40),
};

describe('web release identity', () => {
  it('updates existing clients when another patch uses the same build number', () => {
    const first = prepareWebRelease(input);
    const second = prepareWebRelease({ ...input, entrypoint: 'console.log("second patch");' });
    expect(second.release.version).toBe(first.release.version);
    expect(second.release.cacheVersion).not.toBe(first.release.cacheVersion);
    expect(second.bootstrap).toContain(`serviceWorkerVersion: "${second.release.cacheVersion}"`);
  });

  it('also updates for changes in the worker resource manifest', () => {
    expect(prepareWebRelease({ ...input, worker: `${input.worker}\n// updated resource` }).release.cacheVersion)
      .not.toBe(prepareWebRelease(input).release.cacheVersion);
  });

  it('is reproducible and idempotent while retaining the deployed revision', () => {
    const first = prepareWebRelease(input);
    expect(prepareWebRelease({ ...input, bootstrap: first.bootstrap })).toEqual(first);
    expect(first.release.revision).toBe(input.revision);
    expect(first.release.cacheVersion).toMatch(/^0\.6\.4-build\.27-[0-9a-f]{20}$/);
  });

  it('updates for asset-only revisions even if the worker is a cleanup stub', () => {
    const stub = { ...input, worker: 'self.addEventListener("activate", () => {});' };
    expect(prepareWebRelease({ ...stub, revision: 'b'.repeat(40) }).release.cacheVersion)
      .not.toBe(prepareWebRelease(stub).release.cacheVersion);
  });

  it.each([
    { bootstrap: 'no service worker marker' },
    { bootstrap: `${input.bootstrap}${input.bootstrap}` },
    { worker: '' },
    { entrypoint: '' },
    { version: 'unknown' },
    { revision: 'not-a-commit' },
  ])('rejects incomplete or ambiguous build output: %j', (invalid) => {
    expect(() => prepareWebRelease({ ...input, ...invalid })).toThrow();
  });
});
