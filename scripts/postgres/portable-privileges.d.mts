export type PortableGrant = {
  grantee: 'PUBLIC' | 'hdc_app';
  privilege: string;
  grantable: boolean;
};

export type PortablePrivilegeObject = {
  kind: 'SCHEMA' | 'TABLE' | 'SEQUENCE' | 'FUNCTION' | 'PROCEDURE' | 'DOMAIN' | 'TYPE' | 'COLUMN';
  schema: 'public';
  name: string;
  identityArguments?: string;
  column?: string;
  grants: PortableGrant[];
};

export type PortablePrivileges = {
  version: 1;
  objects: PortablePrivilegeObject[];
};

export const PORTABLE_PRIVILEGES_VERSION: 1;

export function normalizePortablePrivileges(
  snapshot: unknown,
): PortablePrivileges;

export function capturePortablePrivileges(
  sql: { unsafe(query: string): Promise<Record<string, unknown>[]> },
): Promise<PortablePrivileges>;

export function renderPortablePrivilegeStatements(
  snapshot: unknown,
): string[];

export function applyPortablePrivileges(
  sql: {
    unsafe(query: string): Promise<Record<string, unknown>[]>;
    begin<T>(callback: (transaction: {
      unsafe(query: string): Promise<unknown>;
    }) => Promise<T>): Promise<T>;
  },
  snapshot: unknown,
): Promise<PortablePrivileges>;
