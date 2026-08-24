import { cp, readFile, stat, writeFile } from 'node:fs/promises';

const buildDirectory = new URL('../build/web/', import.meta.url);
const resetSource = new URL('../public/reset-password/', import.meta.url);
const resetDestination = new URL('../build/web/reset-password/', import.meta.url);
const packageFile = new URL('../package.json', import.meta.url);

await stat(new URL('index.html', buildDirectory));
await cp(resetSource, resetDestination, { recursive: true, force: true });

const packageJson = JSON.parse(await readFile(packageFile, 'utf8'));
await writeFile(
  new URL('hdc-release.json', buildDirectory),
  `${JSON.stringify({ service: 'hdc-web', version: packageJson.version })}\n`,
  'utf8',
);
