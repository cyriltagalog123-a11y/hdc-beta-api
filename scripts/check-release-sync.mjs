import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const read = (path) => readFile(new URL(path, root), 'utf8');

const collectFiles = async (path) => {
  const entries = await readdir(new URL(`${path}/`, root), {
    withFileTypes: true,
  });
  const files = [];

  for (const entry of entries) {
    const relativePath = `${path}/${entry.name}`;
    if (entry.isDirectory()) {
      files.push(...(await collectFiles(relativePath)));
    } else if (entry.isFile()) {
      files.push(relativePath);
    }
  }

  return files;
};

const packageJson = JSON.parse(await read('package.json'));
const release = /^(\d+\.\d+\.\d+)-build\.(\d+)$/.exec(packageJson.version);
assert.ok(release, 'package.json must use x.y.z-build.N');
const [, semanticVersion, buildNumber] = release;

const expected = {
  flutter: `version: ${semanticVersion}+${buildNumber}`,
  app: `${semanticVersion} Beta (Build ${buildNumber})`,
  splash: `BUILD ${buildNumber} • HDC NETWORK`,
  login: `CONTROLLED BETA • BUILD ${buildNumber}`,
  footer: `HelpDesk Connect Beta v${semanticVersion} Build ${buildNumber}`,
  health: `${semanticVersion}-build${buildNumber}`,
  startup: `Build ${buildNumber}`,
  recovery: `Build ${buildNumber}`,
};
const files = {
  flutter: await read('pubspec.yaml'),
  app: await read('lib/core/config/app_config.dart'),
  splash: await read('lib/features/splash/splash_screen.dart'),
  login: await read('lib/features/authentication/login_screen.dart'),
  footer: await read('lib/features/dashboard/dashboard_screen.dart'),
  health: await read('netlify/functions/api.mts'),
  startup: await read('web/index.html'),
  recovery: await read('web/hdc_startup.js'),
};
for (const [target, marker] of Object.entries(expected)) {
  assert.ok(
    files[target].includes(marker),
    `${target} release marker is not synchronized: expected ${marker}`,
  );
}

const userFacingSourceFiles = [
  ...(await collectFiles('lib')).filter((path) => path.endsWith('.dart')),
  ...(await collectFiles('web')).filter((path) => /\.(?:html|js)$/.test(path)),
];
const staleReleaseMarkers = [];
const buildMarkerPattern = /\b(?:BUILD|Build)\s+(\d+)\b/g;

for (const path of userFacingSourceFiles) {
  const source = await read(path);
  const visibleSource = source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/^\s*\/\/.*$/gm, '');

  for (const match of visibleSource.matchAll(buildMarkerPattern)) {
    if (match[1] !== buildNumber) {
      staleReleaseMarkers.push(`${path}: ${match[0]}`);
    }
  }
}

assert.equal(
  staleReleaseMarkers.length,
  0,
  `Stale user-facing build markers found:\n${staleReleaseMarkers.join('\n')}`,
);

const ci = await read('.github/workflows/ci.yml');
assert.ok(
  !ci.includes('git push origin'),
  'CI must validate source without mutating review branches',
);
const netlify = await read('netlify.toml');
assert.ok(
  netlify.includes('command = "bash scripts/netlify-build.sh"'),
  'Netlify must build Flutter web from source',
);

console.log(`HDC release markers synchronized at ${semanticVersion}+${buildNumber}.`);
