export function parseBackupDatabaseUrl(databaseUrl) {
  let parsed;
  try {
    parsed = new URL(databaseUrl);
  } catch {
    throw new Error(
      'HDC_DATABASE_URL must be a valid PostgreSQL connection URL.',
    );
  }

  if (!['postgres:', 'postgresql:'].includes(parsed.protocol)) {
    throw new Error(
      'HDC_DATABASE_URL must use the postgres:// or postgresql:// protocol.',
    );
  }
  if (!parsed.hostname || parsed.pathname === '/' || !parsed.pathname) {
    throw new Error(
      'HDC_DATABASE_URL must include a database host and database name.',
    );
  }
  if (parsed.hostname.toLowerCase().includes('-pooler')) {
    throw new Error(
      'HDC_DATABASE_URL must use a direct (unpooled) PostgreSQL connection for pg_dump.',
    );
  }

  return parsed;
}

export function pgDumpArguments(databaseUrl, outputPath) {
  parseBackupDatabaseUrl(databaseUrl);
  return [
    '--dbname',
    databaseUrl,
    '--format=custom',
    '--no-owner',
    '--no-password',
    '--file',
    outputPath,
  ];
}
