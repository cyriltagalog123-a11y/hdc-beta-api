/**
 * A Netlify preview must never inherit the production database connection.
 * Netlify's URL, SITE_ID and SITE_NAME are available to Functions at runtime;
 * CONTEXT is a build-only variable and cannot protect a running Function.
 */
import {
  firstEnvironment,
  optionalEnvironment,
  processEnvironmentReader,
  type EnvironmentReader,
} from '../../../server/core/environment.mjs';

export function databaseUrlForRequest(
  requestUrl: string | undefined,
  environment: EnvironmentReader = processEnvironmentReader,
): string {
  const productionUrl = firstEnvironment(environment, ['HDC_DATABASE_URL', 'DATABASE_URL']);
  const siteId = optionalEnvironment(environment, 'SITE_ID');
  const primaryUrl = optionalEnvironment(environment, 'URL');
  const siteName = optionalEnvironment(environment, 'SITE_NAME');
  const isNetlify = Boolean(siteId || primaryUrl || siteName);
  if (!isNetlify) {
    if (!productionUrl) throw new Error('Missing required server environment variable: HDC_DATABASE_URL');
    return productionUrl;
  }

  if (!requestUrl || !siteId || !primaryUrl || !siteName ||
      !/^[a-z0-9][a-z0-9-]*$/.test(siteName)) {
    throw new Error('HDC Netlify deployment database context is incomplete.');
  }

  const request = new URL(requestUrl);
  const primary = new URL(primaryUrl);
  if (request.protocol !== 'https:') {
    throw new Error('HDC database access requires HTTPS on Netlify.');
  }
  // Netlify may represent the primary URL with an HTTP scheme even while its
  // public TLS endpoint serves requests over HTTPS.
  if (request.hostname === primary.hostname ||
      request.hostname === `${siteName}.netlify.app`) {
    if (!productionUrl) throw new Error('Missing required server environment variable: HDC_DATABASE_URL');
    return productionUrl;
  }

  // Deploy Previews and branch deploys use Netlify's site-specific hostname.
  // Other hosts and HTTP fail closed. Deploy permalinks with the same hostname
  // shape also receive only the isolated preview database.
  const suffix = `--${siteName}.netlify.app`;
  const prefix = request.hostname.endsWith(suffix)
    ? request.hostname.slice(0, -suffix.length)
    : '';
  if (!/^(?:deploy-preview-[1-9][0-9]*|[a-z0-9][a-z0-9-]*)$/.test(prefix)) {
    throw new Error('HDC database access is unavailable at this deploy origin.');
  }

  const previewUrl = optionalEnvironment(environment, 'HDC_PREVIEW_DATABASE_URL');
  if (!previewUrl || (productionUrl && previewUrl === productionUrl)) {
    throw new Error('HDC preview requires a distinct isolated database URL.');
  }
  return previewUrl;
}
