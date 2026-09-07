import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const read = (path) => readFile(new URL(path, root), 'utf8');

const packageJson = JSON.parse(await read('package.json'));
const release = /^(\d+\.\d+\.\d+)-build\.(\d+)$/.exec(packageJson.version);
assert.ok(release, 'package.json must use x.y.z-build.N');
const [, semanticVersion, buildNumber] = release;

const expected = {
  flutter: `version: ${semanticVersion}+${buildNumber}`,
  app: `${semanticVersion} Beta (Build ${buildNumber})`,
  login: `CONTROLLED BETA • BUILD ${buildNumber}`,
  footer: `HelpDesk Connect Beta v${semanticVersion} Build ${buildNumber}`,
  health: `${semanticVersion}-build${buildNumber}`,
  startup: `Build ${buildNumber}`,
  recovery: `Build ${buildNumber}`,
};
const files = {
  flutter: await read('pubspec.yaml'),
  app: await read('lib/core/config/app_config.dart'),
  login: await read('lib/features/authentication/login_screen.dart'),
  footer: await read('lib/features/dashboard/dashboard_screen.dart'),
  health: await read('netlify/functions/api.mts'),
  startup: await read('web/index.html'),
  recovery: await read('web/hdc_startup.js'),
};
for (const [target, marker] of Object.entries(expected)) {
  assert.ok(files[target].includes(marker), `${target} release marker is not synchronized: expected ${marker}`);
}

const ci = await read('.github/workflows/ci.yml');
assert.ok(!ci.includes('git push origin'), 'CI must validate source without mutating review branches');
const netlify = await read('netlify.toml');
assert.ok(netlify.includes('command = "bash scripts/netlify-build.sh"'), 'Netlify must build Flutter web from source');

console.log(`HDC release markers synchronized at ${semanticVersion}+${buildNumber}.`);
