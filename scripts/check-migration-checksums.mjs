import { createHash } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const migrationDirectory = join(root, 'migrations');
const manifest = JSON.parse(
  readFileSync(join(migrationDirectory, 'checksums.json'), 'utf8'),
);
if (manifest.algorithm !== 'sha256' || !manifest.files) {
  throw new Error('Invalid HDC migration checksum manifest.');
}

const migrationFiles = readdirSync(migrationDirectory)
  .filter((name) => /^[0-9]{4}_.+\.sql$/.test(name))
  .sort();
const recordedFiles = Object.keys(manifest.files).sort();
if (JSON.stringify(migrationFiles) !== JSON.stringify(recordedFiles)) {
  throw new Error('Migration files and checksum manifest do not match.');
}

for (const name of migrationFiles) {
  const checksum = createHash('sha256')
    .update(readFileSync(join(migrationDirectory, name)))
    .digest('hex');
  if (checksum !== manifest.files[name]) {
    throw new Error(`Migration checksum mismatch: ${name}`);
  }
}

console.log(`Verified ${migrationFiles.length} immutable HDC migrations.`);
