export function parseBackupDatabaseUrl(databaseUrl: string): URL;

export function pgDumpArguments(
  databaseUrl: string,
  outputPath: string,
): string[];
