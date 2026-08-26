import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const read = (path) => readFile(new URL(path, root), 'utf8');

const packageJson = JSON.parse(await read('package.json'));
const release = /^(\d+\.\d+\.\d+)-build\.(\d+)$/.exec(
  packageJson.version,
);
assert.ok(release, 'package.json must use x.y.z-build.N');

const [, semanticVersion, buildNumber] = release;
const expected = {
  flutter: `version: ${semanticVersion}+${buildNumber}`,
  app: `${semanticVersion} Beta (Build ${buildNumber})`,
  footer: `HelpDesk Connect Beta v${semanticVersion} Build ${buildNumber}`,
  health: `${semanticVersion}-build${buildNumber}`,
};

const files = {
  flutter: await read('pubspec.yaml'),
  app: await read('lib/core/config/app_config.dart'),
  footer: await read('lib/features/dashboard/dashboard_screen.dart'),
  health: await read('netlify/functions/api.mts'),
};

for (const [target, marker] of Object.entries(expected)) {
  assert.ok(
    files[target].includes(marker),
    `${target} release marker is not synchronized: expected ${marker}`,
  );
}

try {
  const generatedVersion = JSON.parse(await read('build/web/version.json'));
  assert.equal(
    String(generatedVersion.version),
    semanticVersion,
    'generated Flutter web version is stale',
  );
  assert.equal(
    String(generatedVersion.build_number),
    buildNumber,
    'generated Flutter web build number is stale',
  );
} catch (error) {
  if (error?.code !== 'ENOENT') throw error;
}

console.log(`HDC release markers synchronized at ${semanticVersion}+${buildNumber}.`);
