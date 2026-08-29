import { createHash } from 'node:crypto';

import { WorkflowHttpError } from './workflow.mjs';

const ID_RE = /^[A-Za-z0-9._:-]{3,100}$/;

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
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
  optional = false,
): string {
  const value = source[key];
  if (optional && (value === null || value === undefined || value === '')) {
    return '';
  }
  if (typeof value !== 'string') {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      `${key} is invalid.`,
    );
  }
  const normalized = value.trim().replace(/\s+/g, ' ');
  if (normalized.length < minimum || normalized.length > maximum) {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      `${key} is invalid.`,
    );
  }
  return normalized;
}

function structuredText(
  source: Record<string, unknown>,
  key: string,
  minimum: number,
  maximum: number,
): string {
  const value = source[key];
  if (typeof value !== 'string') {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      `${key} is invalid.`,
    );
  }
  const normalized = value.trim().replace(/\r\n?/g, '\n');
  if (
    normalized.length < minimum ||
    normalized.length > maximum ||
    /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/.test(normalized)
  ) {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      `${key} is invalid.`,
    );
  }
  return normalized;
}

function identifier(source: Record<string, unknown>, key: string): string {
  const value = text(source, key, 3, 100);
  if (!ID_RE.test(value)) {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      `${key} is invalid.`,
    );
  }
  return value;
}

function enumValue(
  source: Record<string, unknown>,
  key: string,
  values: readonly string[],
): string {
  const value = source[key];
  if (typeof value !== 'string' || !values.includes(value)) {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      `${key} is invalid.`,
    );
  }
  return value;
}

function integer(
  source: Record<string, unknown>,
  key: string,
  minimum: number,
  maximum: number,
): number {
  const value = source[key];
  if (
    typeof value !== 'number' ||
    !Number.isSafeInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      `${key} is invalid.`,
    );
  }
  return value;
}

function optionalInteger(
  source: Record<string, unknown>,
  key: string,
  minimum: number,
  maximum: number,
): number | null {
  const value = source[key];
  if (value === null || value === undefined || value === '') return null;
  return integer(source, key, minimum, maximum);
}

function dateTime(source: Record<string, unknown>, key: string): string {
  const value = source[key];
  if (typeof value !== 'string') {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      `${key} is invalid.`,
    );
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      `${key} is invalid.`,
    );
  }
  return parsed.toISOString();
}

export type ScheduleChangeWrite = Readonly<{
  clientReference: string;
  proposedFor: string;
  note: string;
}>;

export function parseScheduleChangeWrite(value: unknown): ScheduleChangeWrite {
  const source = object(value);
  return Object.freeze({
    clientReference: identifier(source, 'clientReference'),
    proposedFor: dateTime(source, 'proposedFor'),
    note: text(source, 'note', 0, 1000, true),
  });
}

export type ChangeOrderWrite = Readonly<{
  clientReference: string;
  reason: string;
  serviceFeeMinor: number;
  partsCostMinor: number;
  currency: string;
}>;

export function parseChangeOrderWrite(value: unknown): ChangeOrderWrite {
  const source = object(value);
  const currency = text(source, 'currency', 3, 3).toUpperCase();
  if (currency !== 'PHP') {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      'Service transactions use PHP in this beta.',
    );
  }
  return Object.freeze({
    clientReference: identifier(source, 'clientReference'),
    reason: text(source, 'reason', 5, 2000),
    serviceFeeMinor: integer(source, 'serviceFeeMinor', 0, 100_000_000_000),
    partsCostMinor: integer(source, 'partsCostMinor', 0, 100_000_000_000),
    currency,
  });
}

export type ParticipantDecisionWrite = Readonly<{
  action: 'accept' | 'decline' | 'withdraw';
  note: string;
}>;

export function parseParticipantDecisionWrite(
  value: unknown,
): ParticipantDecisionWrite {
  const source = object(value);
  return Object.freeze({
    action: enumValue(source, 'action', [
      'accept',
      'decline',
      'withdraw',
    ]) as ParticipantDecisionWrite['action'],
    note: text(source, 'note', 0, 1000, true),
  });
}

export type TransactionExceptionWrite = Readonly<{
  clientReference: string;
  exceptionType:
    | 'cancellation'
    | 'customerNoShow'
    | 'technicianNoShow'
    | 'customerNonResponse'
    | 'other';
  reason: string;
}>;

export function parseTransactionExceptionWrite(
  value: unknown,
): TransactionExceptionWrite {
  const source = object(value);
  return Object.freeze({
    clientReference: identifier(source, 'clientReference'),
    exceptionType: enumValue(source, 'exceptionType', [
      'cancellation',
      'customerNoShow',
      'technicianNoShow',
      'customerNonResponse',
      'other',
    ]) as TransactionExceptionWrite['exceptionType'],
    reason: text(source, 'reason', 5, 2000),
  });
}

export type PaymentWrite = Readonly<{
  clientReference: string;
  amountMinor: number;
  currency: string;
  paymentMethod: 'cash' | 'bankTransfer' | 'eWallet' | 'cardExternal' | 'other';
  note: string;
  externalReference: string | null;
}>;

export function parsePaymentWrite(value: unknown): PaymentWrite {
  const source = object(value);
  const currency = text(source, 'currency', 3, 3).toUpperCase();
  if (currency !== 'PHP') {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      'Service transactions use PHP in this beta.',
    );
  }
  const externalReference = text(
    source,
    'externalReference',
    0,
    120,
    true,
  );
  return Object.freeze({
    clientReference: identifier(source, 'clientReference'),
    amountMinor: integer(source, 'amountMinor', 1, 100_000_000_000),
    currency,
    paymentMethod: enumValue(source, 'paymentMethod', [
      'cash',
      'bankTransfer',
      'eWallet',
      'cardExternal',
      'other',
    ]) as PaymentWrite['paymentMethod'],
    note: text(source, 'note', 0, 2000, true),
    externalReference: externalReference || null,
  });
}

export type PaymentActionWrite = Readonly<{
  action:
    | 'confirm'
    | 'reject'
    | 'cancel'
    | 'recordRefund'
    | 'confirmRefund';
  amountMinor: number | null;
  note: string;
}>;

export function parsePaymentActionWrite(value: unknown): PaymentActionWrite {
  const source = object(value);
  const action = enumValue(source, 'action', [
    'confirm',
    'reject',
    'cancel',
    'recordRefund',
    'confirmRefund',
  ]) as PaymentActionWrite['action'];
  const amountMinor = optionalInteger(
    source,
    'amountMinor',
    1,
    100_000_000_000,
  );
  if (
    (action === 'recordRefund' || action === 'confirmRefund') &&
    amountMinor === null
  ) {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      'A refund amount is required.',
    );
  }
  return Object.freeze({
    action,
    amountMinor,
    note: text(source, 'note', 0, 2000, true),
  });
}

export type DocumentWrite = Readonly<{
  clientReference: string;
  documentType:
    | 'serviceReport'
    | 'warranty'
    | 'paymentEvidence'
    | 'receiptNote'
    | 'disputeEvidence'
    | 'other';
  title: string;
  content: string;
  disputeId: string | null;
}>;

export function parseDocumentWrite(value: unknown): DocumentWrite {
  const source = object(value);
  const documentType = enumValue(source, 'documentType', [
    'serviceReport',
    'warranty',
    'paymentEvidence',
    'receiptNote',
    'disputeEvidence',
    'other',
  ]) as DocumentWrite['documentType'];
  const disputeIdValue = source.disputeId;
  const disputeId = disputeIdValue === null || disputeIdValue === undefined ||
      disputeIdValue === ''
    ? null
    : identifier(source, 'disputeId');
  if (documentType === 'disputeEvidence' && disputeId === null) {
    throw new WorkflowHttpError(
      'invalid_transaction_tool_payload',
      400,
      'Dispute evidence must be linked to a dispute.',
    );
  }
  return Object.freeze({
    clientReference: identifier(source, 'clientReference'),
    documentType,
    title: text(source, 'title', 3, 160),
    content: structuredText(source, 'content', 2, 20_000),
    disputeId,
  });
}

export type DisputeWrite = Readonly<{
  clientReference: string;
  reasonCode:
    | 'workQuality'
    | 'scopeOrPrice'
    | 'payment'
    | 'noShow'
    | 'conductOrSafety'
    | 'completion'
    | 'other';
  summary: string;
  requestedOutcome:
    | 'continueService'
    | 'cancelService'
    | 'partialRefund'
    | 'fullRefund'
    | 'other';
}>;

export function parseDisputeWrite(value: unknown): DisputeWrite {
  const source = object(value);
  return Object.freeze({
    clientReference: identifier(source, 'clientReference'),
    reasonCode: enumValue(source, 'reasonCode', [
      'workQuality',
      'scopeOrPrice',
      'payment',
      'noShow',
      'conductOrSafety',
      'completion',
      'other',
    ]) as DisputeWrite['reasonCode'],
    summary: text(source, 'summary', 20, 5000),
    requestedOutcome: enumValue(source, 'requestedOutcome', [
      'continueService',
      'cancelService',
      'partialRefund',
      'fullRefund',
      'other',
    ]) as DisputeWrite['requestedOutcome'],
  });
}

export type DisputeParticipantActionWrite = Readonly<{
  action: 'addNote' | 'withdraw';
  message: string;
}>;

export function parseDisputeParticipantActionWrite(
  value: unknown,
): DisputeParticipantActionWrite {
  const source = object(value);
  const action = enumValue(source, 'action', [
    'addNote',
    'withdraw',
  ]) as DisputeParticipantActionWrite['action'];
  return Object.freeze({
    action,
    message: text(
      source,
      'message',
      action === 'withdraw' ? 5 : 2,
      5000,
    ),
  });
}

export type DisputeResolutionWrite = Readonly<{
  outcome:
    | 'serviceContinues'
    | 'serviceCompleted'
    | 'serviceCancelled'
    | 'partialRefund'
    | 'fullRefund'
    | 'noAdjustment'
    | 'other';
  note: string;
}>;

export function parseDisputeResolutionWrite(
  value: unknown,
): DisputeResolutionWrite {
  const source = object(value);
  return Object.freeze({
    outcome: enumValue(source, 'outcome', [
      'serviceContinues',
      'serviceCompleted',
      'serviceCancelled',
      'partialRefund',
      'fullRefund',
      'noAdjustment',
      'other',
    ]) as DisputeResolutionWrite['outcome'],
    note: text(source, 'note', 10, 5000),
  });
}

function iso(value: unknown): string {
  return new Date(String(value)).toISOString();
}

function optionalIso(value: unknown): string | null {
  return value === null || value === undefined ? null : iso(value);
}

export function scheduleChangeView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    transactionId: String(row.transaction_id),
    proposedBy: String(row.proposed_by),
    proposedFor: iso(row.proposed_for),
    note: String(row.note ?? ''),
    status: String(row.status),
    decidedBy: row.decided_by ? String(row.decided_by) : null,
    decidedAt: optionalIso(row.decided_at),
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
    version: Number(row.version ?? 1),
  };
}

export function changeOrderView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    transactionId: String(row.transaction_id),
    proposedBy: String(row.proposed_by),
    reason: String(row.reason),
    serviceFeeMinor: Number(row.service_fee_minor),
    partsCostMinor: Number(row.parts_cost_minor),
    totalMinor: Number(row.total_minor),
    currency: String(row.currency),
    status: String(row.status),
    decidedBy: row.decided_by ? String(row.decided_by) : null,
    decidedAt: optionalIso(row.decided_at),
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
    version: Number(row.version ?? 1),
  };
}

export function transactionExceptionView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    transactionId: String(row.transaction_id),
    reportedBy: String(row.reported_by),
    exceptionType: String(row.exception_type),
    reason: String(row.reason),
    status: String(row.status),
    createdAt: iso(row.created_at),
    resolvedAt: optionalIso(row.resolved_at),
  };
}

export function paymentView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    transactionId: String(row.transaction_id),
    recordedBy: String(row.recorded_by),
    amountMinor: Number(row.amount_minor),
    currency: String(row.currency),
    paymentMethod: String(row.payment_method),
    status: String(row.status),
    note: String(row.note ?? ''),
    externalReference: row.external_reference
      ? String(row.external_reference)
      : null,
    confirmedBy: row.confirmed_by ? String(row.confirmed_by) : null,
    confirmedAt: optionalIso(row.confirmed_at),
    refundedMinor: Number(row.refunded_minor ?? 0),
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
    version: Number(row.version ?? 1),
  };
}

export function paymentEventView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    paymentId: String(row.payment_id),
    transactionId: String(row.transaction_id),
    actorId: String(row.actor_id),
    relatedEventId: row.related_event_id ? String(row.related_event_id) : null,
    eventType: String(row.event_type),
    amountMinor: row.amount_minor === null || row.amount_minor === undefined
      ? null
      : Number(row.amount_minor),
    note: String(row.note ?? ''),
    createdAt: iso(row.created_at),
  };
}

export function receiptView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    paymentId: String(row.payment_id),
    transactionId: String(row.transaction_id),
    receiptType: String(row.receipt_type),
    amountMinor: Number(row.amount_minor),
    currency: String(row.currency),
    issuedTo: String(row.issued_to),
    issuedBy: String(row.issued_by),
    verificationLevel: String(row.verification_level),
    snapshot: row.snapshot && typeof row.snapshot === 'object'
      ? row.snapshot
      : {},
    issuedAt: iso(row.issued_at),
  };
}

export function documentView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    transactionId: String(row.transaction_id),
    disputeId: row.dispute_id ? String(row.dispute_id) : null,
    createdBy: String(row.created_by),
    documentType: String(row.document_type),
    title: String(row.title),
    content: String(row.content_text),
    contentSha256: String(row.content_sha256),
    byteSize: Number(row.byte_size),
    storageMode: String(row.storage_mode),
    mimeType: String(row.mime_type),
    visibility: String(row.visibility),
    status: String(row.status),
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
    version: Number(row.version ?? 1),
  };
}

export function disputeView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    transactionId: String(row.transaction_id),
    openedBy: String(row.opened_by),
    reasonCode: String(row.reason_code),
    summary: String(row.summary),
    requestedOutcome: String(row.requested_outcome),
    priorTransactionStatus: String(row.prior_transaction_status),
    status: String(row.status),
    resolutionOutcome: row.resolution_outcome
      ? String(row.resolution_outcome)
      : null,
    resolutionNote: String(row.resolution_note ?? ''),
    resolvedBy: row.resolved_by ? String(row.resolved_by) : null,
    resolvedAt: optionalIso(row.resolved_at),
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
    version: Number(row.version ?? 1),
  };
}

export function disputeEventView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    disputeId: String(row.dispute_id),
    transactionId: String(row.transaction_id),
    actorId: String(row.actor_id),
    eventType: String(row.event_type),
    message: String(row.message),
    createdAt: iso(row.created_at),
  };
}

export function contentDigest(content: string): string {
  return createHash('sha256').update(content, 'utf8').digest('hex');
}

export function utf8Bytes(content: string): number {
  return new TextEncoder().encode(content).byteLength;
}

export function targetStatusForDisputeOutcome(
  outcome: DisputeResolutionWrite['outcome'],
): 'inProgress' | 'completed' | 'cancelled' {
  if (outcome === 'serviceCompleted' || outcome === 'noAdjustment') {
    return 'completed';
  }
  if (
    outcome === 'serviceCancelled' ||
    outcome === 'partialRefund' ||
    outcome === 'fullRefund'
  ) {
    return 'cancelled';
  }
  return 'inProgress';
}
