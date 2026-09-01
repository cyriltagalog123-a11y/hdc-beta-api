export const PORTABLE_BACKUP_EXCLUDED_EXTENSIONS: readonly string[];
export const PORTABLE_BACKUP_EXCLUDED_SCHEMAS: readonly string[];

export function parseBackupDatabaseUrl(databaseUrl: string): URL;

export function pgDumpArguments(
  databaseUrl: string,
  outputPath: string,
): string[];
