export type DatabaseReadiness = Readonly<{
  ready: boolean;
  latencyMs: number;
}>;

/**
 * HDC deliberately targets the PostgreSQL protocol rather than a specific
 * PostgreSQL hosting company. Cross-engine SQL portability is not promised.
 */
export interface HdcDatabaseAdapter<TClient> {
  readonly driver: 'postgres';
  open(): TClient;
  close(client: TClient): Promise<void>;
  readiness(client: TClient): Promise<DatabaseReadiness>;
}
