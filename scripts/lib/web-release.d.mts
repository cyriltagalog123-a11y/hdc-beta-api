export function prepareWebRelease(input: {
  bootstrap: string;
  worker: string;
  entrypoint: string;
  version: string;
  revision?: string | null;
}): {
  bootstrap: string;
  release: {
    service: string;
    version: string;
    revision: string | null;
    cacheVersion: string;
  };
};
