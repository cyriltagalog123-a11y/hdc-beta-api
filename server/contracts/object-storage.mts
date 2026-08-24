export type ObjectStorageWrite = Readonly<{
  objectKey: string;
  contentType: string;
  contentLength: number;
  body: ReadableStream<Uint8Array>;
  sha256: string;
}>;

export type StoredObjectReference = Readonly<{
  providerKey: string;
  externalReference: string;
  etag?: string;
}>;

export type StoredObjectRead = Readonly<{
  contentType: string;
  contentLength: number;
  sha256: string;
  body: ReadableStream<Uint8Array>;
}>;

export interface ObjectStorageProvider {
  readonly providerKey: string;
  put(input: ObjectStorageWrite): Promise<StoredObjectReference>;
  read(externalReference: string): Promise<StoredObjectRead>;
  delete(externalReference: string): Promise<void>;
  healthCheck(): Promise<boolean>;
}
