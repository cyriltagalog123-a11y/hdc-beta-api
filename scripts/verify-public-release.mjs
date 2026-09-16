// Read-only release smoke check. Never creates accounts or transaction records.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const origin = process.env.HDC_SMOKE_ORIGIN ?? 'https://hdc-beta-api.netlify.app';
const revision = process.env.HDC_SMOKE_REVISION;
assert.match(revision ?? '', /^[0-9a-f]{40}$/, 'Set HDC_SMOKE_REVISION to the intended source commit.');
const { version } = JSON.parse(readFileSync(new URL('../package.json', import.meta.url)));
const statuses = {};
async function get(path, status = 200, noStore = true) {
  const response = await fetch(new URL(path, origin), {
    headers: { 'Cache-Control': 'no-cache' }, redirect: 'error', signal: AbortSignal.timeout(25000),
  });
  assert.equal(response.status, status, `${path} status`);
  if (noStore) assert.match(response.headers.get('cache-control') ?? '', /no-store/, `${path} cache policy`);
  statuses[path] = response.status;
  return response;
}
const [root, release, health, ready, catalog, directory, knowledge, news] = await Promise.all([
  get('/'), get('/hdc-release.json').then(r => r.json()),
  get('/api/health').then(r => r.json()), get('/api/health/ready').then(r => r.json()),
  get('/api/commerce/catalog').then(r => r.json()), get('/api/discovery/technicians').then(r => r.json()),
  get('/api/knowledge').then(r => r.json()), get('/api/news').then(r => r.json()),
]);
assert.equal(release.revision, revision);
assert.equal(release.version, version);
assert.equal(health.build, version.replace('-build.', '-build'));
assert.equal(health.status, 'ok');
assert.equal(ready.status, 'ready');
for (const name of ['database', 'workflowAuthority', 'privateMessaging', 'transactionTools', 'authBootstrap', 'legalRecords', 'latestSchema']) {
  assert.equal(ready.checks?.[name], 'ok', name);
}
assert.equal(root.headers.get('x-content-type-options'), 'nosniff');
assert.equal(root.headers.get('x-frame-options'), 'DENY');
assert.match(root.headers.get('content-security-policy') ?? '', /default-src 'self'/);
assert.match(root.headers.get('strict-transport-security') ?? '', /max-age=/);
assert.match(await root.text(), /HDC/i);
assert.ok(Array.isArray(catalog.listings));
assert.ok(Array.isArray(directory.technicians));
assert.ok(knowledge && !knowledge.error);
assert.ok(news && !news.error);
const allowed = new Set(['profileId', 'publicMemberId', 'publicName', 'avatarUrl', 'headline',
  'description', 'location', 'contactEmail', 'contactPhone', 'website', 'details',
  'ratingCount', 'averageRating', 'completedServices', 'updatedAt']);
for (const person of directory.technicians) {
  for (const key of Object.keys(person)) assert.ok(allowed.has(key), `Unexpected public technician field: ${key}`);
}
if (directory.technicians.length) {
  const profile = await (await get(`/api/discovery/technicians/${encodeURIComponent(directory.technicians[0].profileId)}`)).json();
  assert.equal(profile.technician.profileId, directory.technicians[0].profileId);
  assert.ok(Array.isArray(profile.reviews) && profile.reviews.length <= 20);
}
for (const path of ['/api/profiles', '/api/notifications', '/api/workflow/bootstrap',
  '/api/commerce/buyer-dashboard', '/api/commerce/seller-dashboard', '/api/community',
  '/api/internal/reports?report=activeMembers', '/api/internal/knowledge', '/api/internal/news',
  '/api/internal/community', '/api/internal/platform-role-admin']) {
  const response = await get(path, 401);
  await response.body?.cancel();
}
for (const path of ['/flutter_bootstrap.js', '/flutter_service_worker.js', '/hdc_startup.js']) {
  const response = await get(path);
  assert.ok((await response.text()).length > 20, `${path} is nonempty`);
}
const invalid = await get('/api/discovery/technicians/not-a-profile-id', 404);
await invalid.body?.cancel();
console.log(JSON.stringify({ origin, revision: release.revision, version: release.version,
  statuses, readiness: ready.checks, publicTechnicianCount: directory.technicians.length,
  publicListingCount: catalog.listings.length, securityHeaders: 'passed' }, null, 2));
