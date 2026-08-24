import {
  optionalEnvironment,
  type EnvironmentReader,
} from './environment.mjs';

export const HDC_OPERATION_MODES = [
  'normal',
  'read_only',
  'maintenance',
  'incident',
] as const;

export type HdcOperationMode = typeof HDC_OPERATION_MODES[number];

export type HdcOperationDecision = Readonly<{
  allowed: boolean;
  errorCode?: 'service_read_only' | 'service_maintenance' | 'service_incident';
  retryAfterSeconds?: number;
}>;

const modeSet = new Set<string>(HDC_OPERATION_MODES);

export function loadOperationMode(reader: EnvironmentReader): HdcOperationMode {
  const value = (
    optionalEnvironment(reader, 'HDC_OPERATION_MODE') ?? 'normal'
  ).toLowerCase();
  if (!modeSet.has(value)) {
    throw new Error('HDC_OPERATION_MODE contains an unsupported value.');
  }
  return value as HdcOperationMode;
}

export function operationDecision(
  mode: HdcOperationMode,
  method: string,
  path: string,
): HdcOperationDecision {
  if (path === '/api/health' || path === '/api/health/ready') {
    return Object.freeze({ allowed: true });
  }
  if (mode === 'normal') return Object.freeze({ allowed: true });
  if (mode === 'read_only' && (method === 'GET' || method === 'HEAD')) {
    return Object.freeze({ allowed: true });
  }
  if (mode === 'read_only') {
    return Object.freeze({
      allowed: false,
      errorCode: 'service_read_only',
      retryAfterSeconds: 300,
    });
  }
  return Object.freeze({
    allowed: false,
    errorCode: mode === 'incident'
      ? 'service_incident'
      : 'service_maintenance',
    retryAfterSeconds: 300,
  });
}
