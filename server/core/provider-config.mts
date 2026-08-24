import {
  optionalEnvironment,
  type EnvironmentReader,
} from './environment.mjs';

export const HDC_PROVIDER_CAPABILITIES = [
  'email',
  'sms',
  'phone_verification',
  'object_storage',
  'payment',
] as const;

export type HdcProviderCapability =
  typeof HDC_PROVIDER_CAPABILITIES[number];

export type HdcProviderFailureMode = 'queue' | 'fail_closed' | 'degrade';

export type HdcProviderSelection = Readonly<{
  capability: HdcProviderCapability;
  providerKey: string;
  configured: boolean;
  failureMode: HdcProviderFailureMode;
}>;

const PROVIDER_KEY_PATTERN = /^[a-z][a-z0-9_-]{1,47}$/;

const configuration: Record<HdcProviderCapability, {
  environmentName: string;
  failureMode: HdcProviderFailureMode;
}> = {
  email: {
    environmentName: 'HDC_EMAIL_PROVIDER',
    failureMode: 'queue',
  },
  sms: {
    environmentName: 'HDC_SMS_PROVIDER',
    failureMode: 'queue',
  },
  phone_verification: {
    environmentName: 'HDC_PHONE_VERIFICATION_PROVIDER',
    failureMode: 'fail_closed',
  },
  object_storage: {
    environmentName: 'HDC_OBJECT_STORAGE_PROVIDER',
    failureMode: 'fail_closed',
  },
  payment: {
    environmentName: 'HDC_PAYMENT_PROVIDER',
    failureMode: 'fail_closed',
  },
};

export function loadProviderSelection(
  reader: EnvironmentReader,
  capability: HdcProviderCapability,
): HdcProviderSelection {
  const entry = configuration[capability];
  const providerKey = (
    optionalEnvironment(reader, entry.environmentName) ?? 'disabled'
  ).toLowerCase();
  if (!PROVIDER_KEY_PATTERN.test(providerKey)) {
    throw new Error(`${entry.environmentName} contains an invalid provider key.`);
  }
  return Object.freeze({
    capability,
    providerKey,
    configured: providerKey !== 'disabled',
    failureMode: entry.failureMode,
  });
}

export function loadProviderSelections(
  reader: EnvironmentReader,
): readonly HdcProviderSelection[] {
  return Object.freeze(
    HDC_PROVIDER_CAPABILITIES.map(
      (capability) => loadProviderSelection(reader, capability),
    ),
  );
}
