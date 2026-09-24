import postgres from 'postgres';
import type {
  DatabaseReadiness,
  HdcDatabaseAdapter,
} from '../../../server/contracts/database.mjs';
import { databaseDriver } from './env.mjs';
import { databaseUrlForRequest } from './deploy-database.mjs';

export type DbClient = ReturnType<typeof postgres>;
export type DbJsonValue = postgres.JSONValue;

const postgresAdapter = Object.freeze({
  driver: 'postgres',
  open(requestUrl?: string): DbClient {
    databaseDriver();
    return postgres(databaseUrlForRequest(requestUrl), {
      max: 1,
      prepare: false,
      idle_timeout: 10,
      connect_timeout: 10,
    });
  },
  async close(sql: DbClient): Promise<void> {
    await sql.end({ timeout: 2 });
  },
  async readiness(sql: DbClient): Promise<DatabaseReadiness> {
    const startedAt = Date.now();
    const rows = await sql`SELECT 1 AS ready`;
    return Object.freeze({
      ready: rows.length === 1 && Number(rows[0].ready) === 1,
      latencyMs: Date.now() - startedAt,
    });
  },
}) satisfies HdcDatabaseAdapter<DbClient>;

export function openDb(requestUrl?: string): DbClient {
  return postgresAdapter.open(requestUrl);
}

export async function closeDb(sql: DbClient): Promise<void> {
  await postgresAdapter.close(sql);
}

export async function checkDbReadiness(
  sql: DbClient,
): Promise<DatabaseReadiness> {
  return await postgresAdapter.readiness(sql);
}
