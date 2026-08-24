export type StorageOwnershipMode =
  | 'hdc_managed'
  | 'user_owned'
  | 'organization_owned';

export type StorageBinding = Readonly<{
  bindingId: string;
  ownerUserId: string;
  organizationId?: string;
  mode: StorageOwnershipMode;
  providerKey: string;
  status: 'pending' | 'active' | 'degraded' | 'revoked';
  authorizationReference?: string;
}>;

export type StorageMigrationRequest = Readonly<{
  idempotencyKey: string;
  sourceBindingId: string;
  destinationBindingId: string;
  scope: 'attachments' | 'private_messages' | 'exports' | 'all';
  requestedByUserId: string;
}>;

export type StorageMigrationProgress = Readonly<{
  migrationId: string;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';
  copiedObjects: number;
  copiedBytes: number;
}>;

export type StorageMigrationResult = Readonly<{
  migrationId: string;
  copiedObjects: number;
  copiedBytes: number;
  manifestSha256: string;
  completedAt: Date;
}>;

/**
 * Authorizations are represented only by private server references. OAuth
 * access/refresh tokens must never be returned through this contract.
 */
export interface StorageControlPlane {
  binding(bindingId: string): Promise<StorageBinding | null>;
  migration(migrationId: string): Promise<StorageMigrationProgress | null>;
  migrate(request: StorageMigrationRequest): Promise<StorageMigrationResult>;
  revoke(bindingId: string, requestedByUserId: string): Promise<void>;
}
