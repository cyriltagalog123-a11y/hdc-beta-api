import { randomUUID } from 'node:crypto';

const ID_RE = /^[A-Za-z0-9._:-]{3,100}$/;

const REQUEST_STATUSES = new Set([
  'draft',
  'open',
  'receivingOffers',
  'technicianSelected',
  'inProgress',
  'completed',
  'cancelled',
  'expired',
]);

const REQUEST_URGENCIES = new Set([
  'flexible',
  'normal',
  'urgent',
  'emergency',
]);

const PROPOSAL_STATUSES = new Set([
  'draft',
  'submitted',
  'viewed',
  'shortlisted',
  'accepted',
  'declined',
  'expired',
  'withdrawn',
]);

const PARTS_ARRANGEMENTS = new Set([
  'none',
  'customerSupplies',
  'technicianSupplies',
]);

const WARRANTY_TYPES = new Set([
  'none',
  'sevenDays',
  'thirtyDays',
  'ninetyDays',
  'custom',
]);

export type WorkflowUser = {
  id: string;
  displayName: string;
  roles: string[];
  createdAt: string;
};

export type ServiceRequestWrite = {
  id: string;
  title: string;
  categoryId: string;
  categoryName: string;
  description: string;
  location: string;
  preferredDate: string;
  preferredTime: string;
  urgency: string;
  minimumBudget: number | null;
  maximumBudget: number | null;
  status: string;
};

export function serviceRequestWriteMatchesRow(
  row: Record<string, unknown>,
  input: ServiceRequestWrite,
  customerId: string,
): boolean {
  const sameDate = new Date(String(row.preferred_date)).getTime() ===
    new Date(input.preferredDate).getTime();
  const sameOptionalNumber = (value: unknown, expected: number | null) =>
    expected === null
      ? value === null || value === undefined
      : value !== null && value !== undefined && Number(value) === expected;

  return String(row.customer_id) === customerId &&
    String(row.title) === input.title &&
    String(row.category_id) === input.categoryId &&
    String(row.category_name) === input.categoryName &&
    String(row.description) === input.description &&
    String(row.location) === input.location &&
    sameDate &&
    String(row.preferred_time) === input.preferredTime &&
    String(row.urgency) === input.urgency &&
    sameOptionalNumber(row.minimum_budget, input.minimumBudget) &&
    sameOptionalNumber(row.maximum_budget, input.maximumBudget) &&
    String(row.status) === input.status;
}

export type ProposalWrite = {
  id: string;
  requestId: string;
  status: string;
  serviceFee: number;
  partsArrangement: string;
  estimatedPartsCost: number | null;
  earliestArrival: string;
  estimatedDurationMinutes: number;
  warrantyType: string;
  customWarrantyDays: number | null;
  diagnosis: string;
  repairApproach: string;
  professionalNotes: string;
  attachmentIds: string[];
  submittedAt: string | null;
  viewedAt: string | null;
  shortlistedAt: string | null;
  declinedAt: string | null;
  withdrawnAt: string | null;
};

export class WorkflowHttpError extends Error {
  readonly code: string;
  readonly statusCode: number;

  constructor(code: string, statusCode: number, message: string) {
    super(message);
    this.name = 'WorkflowHttpError';
    this.code = code;
    this.statusCode = statusCode;
  }
}

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new WorkflowHttpError(
      'invalid_workflow_payload',
      400,
      'A JSON object is required.',
    );
  }
  return value as Record<string, unknown>;
}

function text(
  source: Record<string, unknown>,
  key: string,
  minimum: number,
  maximum: number,
): string {
  const value = source[key];
  if (typeof value !== 'string') {
    throw new WorkflowHttpError('invalid_workflow_payload', 400, `${key} is invalid.`);
  }
  const normalized = value.trim().replace(/\s+/g, ' ');
  if (normalized.length < minimum || normalized.length > maximum) {
    throw new WorkflowHttpError('invalid_workflow_payload', 400, `${key} is invalid.`);
  }
  return normalized;
}

function identifier(source: Record<string, unknown>, key: string): string {
  const value = text(source, key, 3, 100);
  if (!ID_RE.test(value)) {
    throw new WorkflowHttpError('invalid_workflow_payload', 400, `${key} is invalid.`);
  }
  return value;
}

function dateTime(
  source: Record<string, unknown>,
  key: string,
  optional = false,
): string | null {
  const value = source[key];
  if (optional && (value === null || value === undefined || value === '')) return null;
  if (typeof value !== 'string') {
    throw new WorkflowHttpError('invalid_workflow_payload', 400, `${key} is invalid.`);
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new WorkflowHttpError('invalid_workflow_payload', 400, `${key} is invalid.`);
  }
  return parsed.toISOString();
}

function finiteNumber(
  source: Record<string, unknown>,
  key: string,
  minimum: number,
  maximum: number,
  optional = false,
): number | null {
  const value = source[key];
  if (optional && (value === null || value === undefined || value === '')) return null;
  if (typeof value !== 'number' || !Number.isFinite(value) || value < minimum || value > maximum) {
    throw new WorkflowHttpError('invalid_workflow_payload', 400, `${key} is invalid.`);
  }
  return value;
}

function integer(
  source: Record<string, unknown>,
  key: string,
  minimum: number,
  maximum: number,
  optional = false,
): number | null {
  const value = finiteNumber(source, key, minimum, maximum, optional);
  if (value === null) return null;
  if (!Number.isInteger(value)) {
    throw new WorkflowHttpError('invalid_workflow_payload', 400, `${key} is invalid.`);
  }
  return value;
}

function enumValue(
  source: Record<string, unknown>,
  key: string,
  allowed: Set<string>,
): string {
  const value = source[key];
  if (typeof value !== 'string' || !allowed.has(value)) {
    throw new WorkflowHttpError('invalid_workflow_payload', 400, `${key} is invalid.`);
  }
  return value;
}

function stringArray(source: Record<string, unknown>, key: string): string[] {
  const value = source[key];
  if (value === null || value === undefined) return [];
  if (!Array.isArray(value) || value.length > 20) {
    throw new WorkflowHttpError('invalid_workflow_payload', 400, `${key} is invalid.`);
  }
  return value.map((item) => {
    if (typeof item !== 'string' || !ID_RE.test(item) || item.length > 100) {
      throw new WorkflowHttpError('invalid_workflow_payload', 400, `${key} is invalid.`);
    }
    return item;
  });
}

export function parseServiceRequestWrite(value: unknown): ServiceRequestWrite {
  const source = record(value);
  const minimumBudget = finiteNumber(source, 'minimumBudget', 0, 100_000_000, true);
  const maximumBudget = finiteNumber(source, 'maximumBudget', 0, 100_000_000, true);
  if (minimumBudget !== null && maximumBudget !== null && minimumBudget > maximumBudget) {
    throw new WorkflowHttpError(
      'invalid_workflow_payload',
      400,
      'minimumBudget cannot exceed maximumBudget.',
    );
  }

  return {
    id: identifier(source, 'id'),
    title: text(source, 'title', 4, 140),
    categoryId: text(source, 'categoryId', 1, 100),
    categoryName: text(source, 'categoryName', 2, 100),
    description: text(source, 'description', 10, 5000),
    location: text(source, 'location', 2, 300),
    preferredDate: dateTime(source, 'preferredDate')!,
    preferredTime: text(source, 'preferredTime', 1, 80),
    urgency: enumValue(source, 'urgency', REQUEST_URGENCIES),
    minimumBudget,
    maximumBudget,
    status: enumValue(source, 'status', REQUEST_STATUSES),
  };
}

export function parseProposalWrite(value: unknown): ProposalWrite {
  const source = record(value);
  const warrantyType = enumValue(source, 'warrantyType', WARRANTY_TYPES);
  const customWarrantyDays = integer(source, 'customWarrantyDays', 1, 3650, true);
  if ((warrantyType === 'custom') !== (customWarrantyDays !== null)) {
    throw new WorkflowHttpError(
      'invalid_workflow_payload',
      400,
      'customWarrantyDays must match a custom warranty.',
    );
  }

  const partsArrangement = enumValue(source, 'partsArrangement', PARTS_ARRANGEMENTS);
  const estimatedPartsCost = finiteNumber(
    source,
    'estimatedPartsCost',
    0,
    100_000_000,
    true,
  );
  if (partsArrangement !== 'technicianSupplies' && estimatedPartsCost !== null) {
    throw new WorkflowHttpError(
      'invalid_workflow_payload',
      400,
      'Parts cost is only valid when the technician supplies parts.',
    );
  }

  return {
    id: identifier(source, 'id'),
    requestId: identifier(source, 'requestId'),
    status: enumValue(source, 'status', PROPOSAL_STATUSES),
    serviceFee: finiteNumber(source, 'serviceFee', 0, 100_000_000)!,
    partsArrangement,
    estimatedPartsCost,
    earliestArrival: dateTime(source, 'earliestArrival')!,
    estimatedDurationMinutes: integer(
      source,
      'estimatedDurationMinutes',
      1,
      43_200,
    )!,
    warrantyType,
    customWarrantyDays,
    diagnosis: text(source, 'diagnosis', 1, 5000),
    repairApproach: text(source, 'repairApproach', 1, 5000),
    professionalNotes: typeof source.professionalNotes === 'string'
      ? source.professionalNotes.trim().slice(0, 5000)
      : '',
    attachmentIds: stringArray(source, 'attachmentIds'),
    submittedAt: dateTime(source, 'submittedAt', true),
    viewedAt: dateTime(source, 'viewedAt', true),
    shortlistedAt: dateTime(source, 'shortlistedAt', true),
    declinedAt: dateTime(source, 'declinedAt', true),
    withdrawnAt: dateTime(source, 'withdrawnAt', true),
  };
}

export function proposalQualityScore(proposal: ProposalWrite, now = new Date()): number {
  let score = 20;
  if (proposal.serviceFee > 0) score += 15;
  if (new Date(proposal.earliestArrival).getTime() > now.getTime()) score += 10;
  if (proposal.estimatedDurationMinutes > 0) score += 10;
  if (proposal.diagnosis.length >= 30) score += 15;
  if (proposal.repairApproach.length >= 30) score += 15;
  if (proposal.professionalNotes.length >= 20) score += 5;
  if (proposal.warrantyType !== 'none') score += 5;
  if (proposal.partsArrangement !== 'none') score += 5;
  return Math.max(0, Math.min(100, score));
}

export function technicianReputation(
  user: WorkflowUser,
): Record<string, string | number | boolean | null> {
  const created = new Date(user.createdAt);
  return {
    technicianName: user.displayName,
    isVerified: false,
    rating: 0,
    completedJobs: 0,
    averageResponseMinutes: 0,
    successRate: 0,
    memberSinceYear: Number.isNaN(created.getTime())
      ? new Date().getUTCFullYear()
      : created.getUTCFullYear(),
  };
}

export function canCustomerUpdateRequestStatus(current: string, next: string): boolean {
  if (current === next) return true;
  if (next !== 'cancelled') return false;
  return current === 'draft' || current === 'open' || current === 'receivingOffers';
}

export function canTechnicianUpdateProposalStatus(current: string, next: string): boolean {
  if (current === next) return true;
  if (current === 'draft' && next === 'submitted') return true;
  if (
    next === 'withdrawn' &&
    (current === 'submitted' || current === 'viewed' || current === 'shortlisted')
  ) return true;
  return false;
}

export function canCustomerUpdateProposalStatus(current: string, next: string): boolean {
  if (current === next) return true;
  if (current === 'submitted' && (next === 'viewed' || next === 'shortlisted' || next === 'declined')) {
    return true;
  }
  if (current === 'viewed' && (next === 'shortlisted' || next === 'declined')) return true;
  if (current === 'shortlisted' && (next === 'viewed' || next === 'declined')) return true;
  return false;
}

export type TransactionTransition = {
  activityType: string;
  message: string;
  requestStatus: string | null;
};

export function transactionTransition(
  current: string,
  next: string,
  actorRole: 'customer' | 'technician',
): TransactionTransition | null {
  if (['completed', 'cancelled', 'disputed'].includes(current) || current === next) return null;

  let allowed = false;
  if (next === 'disputed') {
    allowed = true;
  } else if (next === 'cancelled') {
    allowed = actorRole === 'customer' &&
      current !== 'inProgress' &&
      current !== 'awaitingCustomerConfirmation';
  } else if (actorRole === 'technician') {
    allowed = (
      (current === 'confirmed' && next === 'scheduled') ||
      (current === 'scheduled' && next === 'technicianEnRoute') ||
      (current === 'technicianEnRoute' && next === 'arrived') ||
      (current === 'arrived' && next === 'inProgress') ||
      (current === 'inProgress' && next === 'awaitingCustomerConfirmation')
    );
  } else {
    allowed = current === 'awaitingCustomerConfirmation' && next === 'completed';
  }

  if (!allowed) return null;

  const activity = next === 'completed'
    ? ['completed', 'Customer confirmed service completion.']
    : next === 'cancelled'
      ? ['cancelled', 'The service transaction was cancelled.']
      : next === 'disputed'
        ? ['disputeOpened', 'A dispute was opened for this service transaction.']
        : ['statusChanged', `Service status changed to ${next}.`];

  const requestStatus = next === 'completed'
    ? 'completed'
    : next === 'cancelled'
      ? 'cancelled'
      : (next === 'inProgress' || next === 'awaitingCustomerConfirmation')
        ? 'inProgress'
        : null;

  return {
    activityType: activity[0],
    message: activity[1],
    requestStatus,
  };
}

function iso(value: unknown): string {
  return new Date(String(value)).toISOString();
}

function optionalIso(value: unknown): string | null {
  return value === null || value === undefined ? null : iso(value);
}

function numeric(value: unknown): number {
  return Number(value);
}

function jsonObject(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function jsonArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export function serviceRequestView(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: String(row.id),
    customerId: String(row.customer_id),
    customerName: String(row.customer_name),
    title: String(row.title),
    categoryId: String(row.category_id),
    categoryName: String(row.category_name),
    description: String(row.description),
    location: String(row.location),
    preferredDate: iso(row.preferred_date),
    preferredTime: String(row.preferred_time),
    urgency: String(row.urgency),
    minimumBudget: row.minimum_budget === null ? null : numeric(row.minimum_budget),
    maximumBudget: row.maximum_budget === null ? null : numeric(row.maximum_budget),
    status: String(row.status),
    offerCount: numeric(row.offer_count),
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
  };
}

export function proposalView(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: String(row.id),
    requestId: String(row.request_id),
    technicianId: String(row.technician_id),
    status: String(row.status),
    serviceFee: numeric(row.service_fee),
    partsArrangement: String(row.parts_arrangement),
    estimatedPartsCost: row.estimated_parts_cost === null
      ? null
      : numeric(row.estimated_parts_cost),
    earliestArrival: iso(row.earliest_arrival),
    estimatedDurationMinutes: numeric(row.estimated_duration_minutes),
    warrantyType: String(row.warranty_type),
    customWarrantyDays: row.custom_warranty_days === null
      ? null
      : numeric(row.custom_warranty_days),
    diagnosis: String(row.diagnosis),
    repairApproach: String(row.repair_approach),
    professionalNotes: String(row.professional_notes),
    reputation: jsonObject(row.reputation),
    qualityScore: numeric(row.quality_score),
    attachmentIds: jsonArray(row.attachment_ids),
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
    submittedAt: optionalIso(row.submitted_at),
    viewedAt: optionalIso(row.viewed_at),
    shortlistedAt: optionalIso(row.shortlisted_at),
    acceptedAt: optionalIso(row.accepted_at),
    declinedAt: optionalIso(row.declined_at),
    expiredAt: optionalIso(row.expired_at),
    withdrawnAt: optionalIso(row.withdrawn_at),
  };
}

export function transactionSeedView(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: String(row.id),
    requestId: String(row.request_id),
    proposalId: String(row.proposal_id),
    customerId: String(row.customer_id),
    technicianId: String(row.technician_id),
    acceptedEstimate: numeric(row.accepted_estimate),
    status: String(row.status),
    createdAt: iso(row.created_at),
  };
}

export function serviceTransactionView(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: String(row.id),
    seedId: String(row.seed_id),
    requestId: String(row.request_id),
    proposalId: String(row.proposal_id),
    customerId: String(row.customer_id),
    customerName: String(row.customer_name),
    technicianId: String(row.technician_id),
    technicianName: String(row.technician_name),
    requestTitle: String(row.request_title),
    categoryName: String(row.category_name),
    serviceLocation: String(row.service_location),
    status: String(row.status),
    acceptedTerms: jsonObject(row.accepted_terms),
    activity: jsonArray(row.activity),
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
  };
}

export function newWorkflowId(prefix: string): string {
  return `${prefix}-${randomUUID()}`;
}
