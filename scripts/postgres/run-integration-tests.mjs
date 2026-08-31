import { spawnSync } from 'node:child_process';

const databaseUrl = process.env.HDC_TEST_DATABASE_URL?.trim();
if (!databaseUrl) {
  throw new Error('HDC_TEST_DATABASE_URL is required for PostgreSQL tests.');
}

const result = spawnSync(
  process.execPath,
  [
    'node_modules/vitest/vitest.mjs',
    'run',
    'tests/postgres-workflows.integration.test.ts',
  ],
  {
    env: {
      ...process.env,
      HDC_DATABASE_URL: databaseUrl,
      HDC_POSTGRES_INTEGRATION: '1',
      HDC_SESSION_SECRET:
        process.env.HDC_SESSION_SECRET ??
        'hdc-isolated-integration-session-secret-2026',
      HDC_RECOVERY_PEPPER:
        process.env.HDC_RECOVERY_PEPPER ??
        'hdc-isolated-integration-recovery-pepper-2026',
      HDC_IDENTITY_FINGERPRINT_SECRET:
        process.env.HDC_IDENTITY_FINGERPRINT_SECRET ??
        'hdc-isolated-integration-fingerprint-secret-2026',
      HDC_OPERATION_MODE: 'normal',
    },
    stdio: 'inherit',
  },
);
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);
