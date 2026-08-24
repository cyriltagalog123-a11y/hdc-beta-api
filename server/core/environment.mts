export type EnvironmentReader = (name: string) => string | undefined;

/**
 * Default reader for Node-compatible runtimes. Other hosting adapters can
 * inject their own reader without changing HDC domain code.
 */
export const processEnvironmentReader: EnvironmentReader = (name) => {
  if (typeof process === 'undefined') return undefined;
  return process.env[name];
};

export function optionalEnvironment(
  reader: EnvironmentReader,
  name: string,
): string | null {
  const value = reader(name)?.trim();
  return value ? value : null;
}

export function requiredEnvironment(
  reader: EnvironmentReader,
  name: string,
): string {
  const value = optionalEnvironment(reader, name);
  if (!value) {
    throw new Error(`Missing required server environment variable: ${name}`);
  }
  return value;
}

export function firstEnvironment(
  reader: EnvironmentReader,
  names: readonly string[],
): string | null {
  for (const name of names) {
    const value = optionalEnvironment(reader, name);
    if (value) return value;
  }
  return null;
}
