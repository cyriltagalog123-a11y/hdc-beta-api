import type { StoredObjectReference } from './object-storage.mjs';

export type DataExportScope = Readonly<{
  kind: 'member' | 'organization' | 'platform';
  entityId: string;
}>;

export type PortableDataExport = Readonly<{
  exportId: string;
  schemaVersion: string;
  scope: DataExportScope;
  object: StoredObjectReference;
  manifestSha256: string;
  createdAt: Date;
  expiresAt?: Date;
}>;

export interface DataExportProvider {
  createExport(
    scope: DataExportScope,
    requestedByUserId: string,
  ): Promise<PortableDataExport>;
}
