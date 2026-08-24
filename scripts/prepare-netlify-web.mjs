import { cp, readFile, stat, writeFile } from 'node:fs/promises';

const buildDirectory = new URL('../build/web/', import.meta.url);
const resetSource = new URL('../public/reset-password/', import.meta.url);
const resetDestination = new URL('../build/web/reset-password/', import.meta.url);
const packageFile = new URL('../package.json', import.meta.url);

await stat(new URL('index.html', buildDirectory));

const flutterBootstrap = await readFile(
  new URL('flutter_bootstrap.js', buildDirectory),
  'utf8',
);
if (!flutterBootstrap.includes('"useLocalCanvasKit":true')) {
  throw new Error(
    'Flutter web renderer resources must be self-hosted. Build with --no-web-resources-cdn.',
  );
}

const fontManifest = JSON.parse(
  await readFile(new URL('assets/FontManifest.json', buildDirectory), 'utf8'),
);
const localRoboto = fontManifest
  .find((entry) => entry.family === 'Roboto')
  ?.fonts?.find((font) => font.asset === 'fonts/fallback/Roboto-Regular.ttf');
if (!localRoboto) {
  throw new Error('The self-hosted Roboto fallback font is missing.');
}
await stat(
  new URL('assets/fonts/fallback/Roboto-Regular.ttf', buildDirectory),
);

await cp(resetSource, resetDestination, { recursive: true, force: true });

const packageJson = JSON.parse(await readFile(packageFile, 'utf8'));
await writeFile(
  new URL('hdc-release.json', buildDirectory),
  `${JSON.stringify({ service: 'hdc-web', version: packageJson.version })}\n`,
  'utf8',
);
