import { createHash } from 'node:crypto';

// A build number can contain several patches. Existing Flutter service-worker
// registrations need a new identifier when the compiled application changes.
export function prepareWebRelease({ bootstrap, worker, entrypoint, version, revision = null }) {
  if (!/^\d+\.\d+\.\d+-build\.\d+$/.test(version)) {
    throw new Error('Invalid HDC release version.');
  }
  if (revision !== null && !/^[a-f0-9]{40}$/i.test(revision)) {
    throw new Error('Invalid HDC release revision.');
  }
  if (!worker.trim() || !entrypoint.trim()) {
    throw new Error('The compiled Flutter application and service worker are required.');
  }
  const marker = /serviceWorkerVersion:\s*["'][^"']+["']/g;
  if ([...bootstrap.matchAll(marker)].length !== 1) {
    throw new Error('Expected one Flutter service-worker version marker.');
  }
  const digest = createHash('sha256')
    // The revision also covers asset-only patches when Flutter emits its
    // service-worker cleanup stub instead of a resource manifest.
    .update(revision ?? '')
    .update('\0')
    .update(worker)
    .update('\0')
    .update(entrypoint)
    .digest('hex')
    .slice(0, 20);
  const cacheVersion = `${version}-${digest}`;
  return {
    bootstrap: bootstrap.replace(marker, `serviceWorkerVersion: "${cacheVersion}"`),
    release: { service: 'hdc-web', version, revision, cacheVersion },
  };
}
