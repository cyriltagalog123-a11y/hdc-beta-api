import postgres from 'postgres';
import { databaseUrl } from './env.mjs';

export type DbClient = ReturnType<typeof postgres>;

export function openDb(): DbClient {
  return postgres(databaseUrl(), {
    max: 1,
    prepare: false,
    idle_timeout: 10,
    connect_timeout: 10,
  });
}

export async function closeDb(sql: DbClient): Promise<void> {
  await sql.end({ timeout: 2 });
}
