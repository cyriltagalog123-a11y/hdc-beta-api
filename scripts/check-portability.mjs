import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const failures = [];

function walk(path) {
  if (!statSync(path).isDirectory()) return [path];
  return readdirSync(path).flatMap((name) => walk(join(path, name)));
}

function source(path) {
  return readFileSync(path, 'utf8');
}

function report(path, message) {
  failures.push(`${relative(root, path)}: ${message}`);
}

const dartFiles = walk(join(root, 'lib')).filter((path) => path.endsWith('.dart'));
for (const path of dartFiles) {
  const text = source(path);
  if (/\b(?:DATABASE_URL|HDC_DATABASE_URL|HDC_SESSION_SECRET|HDC_RECOVERY_PEPPER)\b/.test(text)) {
    report(path, 'privileged server environment name leaked into Flutter');
  }
  if (/postgres(?:ql)?:\/\//i.test(text)) {
    report(path, 'database connection string leaked into Flutter');
  }
  if (/package:(?:appwrite|postgres|supabase|netlify|neon)[^/]*\//i.test(text)) {
    report(path, 'Flutter imports a provider SDK directly');
  }
}

const serverFiles = [
  ...walk(join(root, 'netlify', 'functions')),
  ...walk(join(root, 'server')),
].filter((path) => /\.(?:mts|ts)$/.test(path));
const testFiles = walk(join(root, 'tests')).filter((path) => path.endsWith('.ts'));

for (const path of serverFiles) {
  const text = source(path);
  if (/Netlify\.env/.test(text)) {
    report(path, 'runtime environment access bypasses the HDC environment boundary');
  }
  if (/process\.env/.test(text) && !path.endsWith(join('server', 'core', 'environment.mts'))) {
    report(path, 'process environment access is not centralized');
  }
  if (/from ['"]postgres['"]/.test(text) && !path.endsWith(join('netlify', 'functions', '_lib', 'db.mts'))) {
    report(path, 'PostgreSQL driver import is outside the database adapter');
  }
  if (/@netlify\/functions/.test(text) && !path.endsWith(join('netlify', 'functions', 'api.mts'))) {
    report(path, 'Netlify SDK import is outside the hosting adapter');
  }
}

for (const path of [...serverFiles, ...testFiles]) {
  const text = source(path);
  const imports = text.matchAll(/(?:from\s+|import\s*)['"](\.[^'"]+)['"]/g);
  for (const match of imports) {
    const reference = match[1];
    const exact = resolve(dirname(path), reference);
    const sourceForm = exact
      .replace(/\.mjs$/, '.mts')
      .replace(/\.js$/, '.ts');
    if (!existsSync(exact) && !existsSync(sourceForm)) {
      report(path, `missing relative module: ${reference}`);
    }
  }
}

const requiredContracts = [
  'server/contracts/database.mts',
  'server/contracts/data-export.mts',
  'server/contracts/object-storage.mts',
  'server/contracts/outbound-delivery.mts',
  'server/contracts/payment.mts',
  'server/contracts/phone-verification.mts',
  'server/contracts/storage-control-plane.mts',
  'server/adapters/node-http.mts',
  'server/core/environment.mts',
  'server/core/operation-mode.mts',
  'server/core/provider-config.mts',
  'server/core/provider-registry.mts',
  'server/core/security-keys.mts',
];
for (const item of requiredContracts) {
  try {
    statSync(join(root, item));
  } catch {
    failures.push(`${item}: required portability contract is missing`);
  }
}

const examplePath = join(root, '.env.example');
for (const [index, line] of source(examplePath).split(/\r?\n/).entries()) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) continue;
  const separator = trimmed.indexOf('=');
  const name = trimmed.slice(0, separator);
  const value = trimmed.slice(separator + 1).trim();
  if (
    value &&
    /(?:SECRET|PASSWORD|TOKEN|DATABASE_URL|PRIVATE_KEY|API_KEY)/.test(name)
  ) {
    report(examplePath, `line ${index + 1} contains a non-empty secret example`);
  }
}

if (failures.length > 0) {
  console.error('HDC portability boundary check failed:');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(
  `HDC portability boundaries verified (${dartFiles.length} Dart files, ${serverFiles.length} server files, ${testFiles.length} backend tests).`,
);
