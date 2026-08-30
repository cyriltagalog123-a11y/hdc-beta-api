import { createHash } from 'node:crypto';
import { cp, mkdir, readFile, stat, writeFile } from 'node:fs/promises';

const buildDirectory = new URL('../build/web/', import.meta.url);
const resetSource = new URL('../public/reset-password/', import.meta.url);
const resetDestination = new URL('../build/web/reset-password/', import.meta.url);
const packageFile = new URL('../package.json', import.meta.url);
const legalDirectory = new URL('../legal/', import.meta.url);

const generatedIndex = await readFile(
  new URL('index.html', buildDirectory),
  'utf8',
);
if (
  !generatedIndex.includes('id="hdc-startup"') ||
  !generatedIndex.includes('src="hdc_startup.js"')
) {
  throw new Error('The Flutter web startup recovery shell is missing.');
}
await stat(new URL('hdc_startup.css', buildDirectory));
await stat(new URL('hdc_startup.js', buildDirectory));
const packageJson = JSON.parse(await readFile(packageFile, 'utf8'));

const escapeHtml = (value) => value
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;')
  .replaceAll("'", '&#39;');

function legalBody(source) {
  const lines = source.trim().split(/\r?\n/);
  return lines.map((line, index) => {
    const normalized = line.trim();
    if (!normalized) return '';
    const linked = escapeHtml(normalized).replace(
      /(https:\/\/[^\s<]+)/g,
      '<a href="$1" rel="noreferrer">$1</a>',
    );
    if (index === 0) return `<h1>${linked}</h1>`;
    if (/^(?:\d+\.|LEGAL REFERENCES$)/.test(normalized)) {
      return `<h2>${linked}</h2>`;
    }
    if (/^(?:Version|Effective):/.test(normalized)) {
      return `<p class="meta">${linked}</p>`;
    }
    return `<p>${linked}</p>`;
  }).join('\n');
}

function legalPage({ title, description, source, otherPath, otherLabel }) {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${escapeHtml(description)}">
  <meta name="theme-color" content="#0b1f3a">
  <title>${escapeHtml(title)}</title>
  <style>
    :root { color-scheme: light; font-family: Arial, sans-serif; }
    body { margin: 0; color: #172033; background: #f4f7fb; line-height: 1.6; }
    header { background: #0b1f3a; color: white; padding: 18px 24px; }
    nav { max-width: 900px; margin: auto; display: flex; gap: 18px; flex-wrap: wrap; }
    nav a { color: white; font-weight: 700; }
    main { max-width: 900px; margin: 28px auto; padding: 0 20px 48px; }
    article { background: white; border: 1px solid #dce4ef; border-radius: 18px; padding: 30px; box-shadow: 0 8px 28px rgba(11,31,58,.08); }
    h1 { margin-top: 0; line-height: 1.25; color: #0b1f3a; }
    h2 { margin-top: 32px; font-size: 1.15rem; color: #0b1f3a; }
    p { overflow-wrap: anywhere; }
    .meta { margin: 2px 0; color: #52627a; font-weight: 700; }
    a { color: #075ea8; }
    @media (max-width: 600px) { article { padding: 22px; } }
  </style>
</head>
<body>
  <header><nav aria-label="Legal documents"><a href="/">HelpDesk Connect</a><a href="${otherPath}">${otherLabel}</a></nav></header>
  <main><article>${legalBody(source)}</article></main>
</body>
</html>\n`;
}

const legalDocuments = [
  {
    file: 'terms-of-service-beta-2026-08-29.txt',
    path: 'terms',
    title: 'HDC Beta Terms of Service',
    description: 'The current HelpDesk Connect beta terms of service.',
    otherPath: '/legal/privacy/',
    otherLabel: 'Privacy Notice',
  },
  {
    file: 'privacy-notice-beta-2026-08-29.txt',
    path: 'privacy',
    title: 'HDC Beta Privacy Notice',
    description: 'The current HelpDesk Connect beta privacy notice.',
    otherPath: '/legal/terms/',
    otherLabel: 'Terms of Service',
  },
];
for (const document of legalDocuments) {
  const source = await readFile(new URL(document.file, legalDirectory), 'utf8');
  const destination = new URL(`legal/${document.path}/`, buildDirectory);
  await mkdir(destination, { recursive: true });
  await writeFile(
    new URL('index.html', destination),
    legalPage({ ...document, source }),
    'utf8',
  );
  await writeFile(
    new URL('integrity.json', destination),
    `${JSON.stringify({
      version: 'beta-2026-08-29',
      sha256: createHash('sha256').update(source).digest('hex'),
    })}\n`,
    'utf8',
  );
}

const flutterBootstrap = await readFile(
  new URL('flutter_bootstrap.js', buildDirectory),
  'utf8',
);
if (!flutterBootstrap.includes('"useLocalCanvasKit":true')) {
  throw new Error(
    'Flutter web renderer resources must be self-hosted. Build with --no-web-resources-cdn.',
  );
}
const normalizedBootstrap = flutterBootstrap.replace(
  /serviceWorkerVersion: "[^"]+"/,
  `serviceWorkerVersion: "${packageJson.version}"`,
);
if (normalizedBootstrap === flutterBootstrap) {
  throw new Error('Flutter service-worker version marker could not be normalized.');
}
await writeFile(
  new URL('flutter_bootstrap.js', buildDirectory),
  normalizedBootstrap,
  'utf8',
);

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

await writeFile(
  new URL('hdc-release.json', buildDirectory),
  `${JSON.stringify({ service: 'hdc-web', version: packageJson.version })}\n`,
  'utf8',
);
