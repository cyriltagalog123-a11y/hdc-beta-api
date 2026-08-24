import type { HdcProviderSelection } from './provider-config.mjs';

export interface KeyedProvider {
  readonly providerKey: string;
}

export class HdcProviderUnavailableError extends Error {
  readonly capability: HdcProviderSelection['capability'];

  constructor(selection: HdcProviderSelection) {
    super(
      selection.configured
        ? `The configured ${selection.capability} provider is unavailable.`
        : `${selection.capability} is not configured.`,
    );
    this.name = 'HdcProviderUnavailableError';
    this.capability = selection.capability;
  }
}

export class HdcProviderRegistry<TProvider extends KeyedProvider> {
  readonly #providers: ReadonlyMap<string, TProvider>;

  constructor(providers: readonly TProvider[]) {
    const entries = new Map<string, TProvider>();
    for (const provider of providers) {
      if (entries.has(provider.providerKey)) {
        throw new Error(`Duplicate HDC provider key: ${provider.providerKey}`);
      }
      entries.set(provider.providerKey, provider);
    }
    this.#providers = entries;
  }

  optional(selection: HdcProviderSelection): TProvider | null {
    if (!selection.configured) return null;
    return this.#providers.get(selection.providerKey) ?? null;
  }

  required(selection: HdcProviderSelection): TProvider {
    const provider = this.optional(selection);
    if (!provider) throw new HdcProviderUnavailableError(selection);
    return provider;
  }
}
