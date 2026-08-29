import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  contentDigest,
  parseChangeOrderWrite,
  parseDisputeResolutionWrite,
  parseDisputeWrite,
  parseDocumentWrite,
  parsePaymentActionWrite,
  parsePaymentWrite,
  parseScheduleChangeWrite,
  targetStatusForDisputeOutcome,
  utf8Bytes,
} from '../netlify/functions/_lib/transaction-tools.mjs';

describe('transaction toolbox validation', () => {
  it('normalizes schedule and mutually approved price proposals', () => {
    expect(parseScheduleChangeWrite({
      clientReference: 'schedule-1',
      proposedFor: '2026-09-01T09:00:00+08:00',
      note: '  Customer requested morning service. ',
    })).toMatchObject({
      clientReference: 'schedule-1',
      proposedFor: '2026-09-01T01:00:00.000Z',
      note: 'Customer requested morning service.',
    });
    expect(parseChangeOrderWrite({
      clientReference: 'price-1',
      reason: 'A replacement charging port is required.',
      serviceFeeMinor: 120_000,
      partsCostMinor: 35_000,
      currency: 'php',
    })).toMatchObject({ currency: 'PHP', serviceFeeMinor: 120_000 });
    expect(() => parseChangeOrderWrite({
      clientReference: 'price-2',
      reason: 'A replacement charging port is required.',
      serviceFeeMinor: 120_000,
      partsCostMinor: 35_000,
      currency: 'USD',
    })).toThrow(/use PHP/i);
  });

  it('keeps payment records provider-neutral and validates refund amounts', () => {
    expect(parsePaymentWrite({
      clientReference: 'payment-1',
      amountMinor: 155_000,
      currency: 'PHP',
      paymentMethod: 'bankTransfer',
      note: 'Paid through the customer bank.',
      externalReference: 'BANK-123',
    })).toMatchObject({
      paymentMethod: 'bankTransfer',
      externalReference: 'BANK-123',
    });
    expect(() => parsePaymentWrite({
      clientReference: 'payment-2',
      amountMinor: 155_000,
      currency: 'USD',
      paymentMethod: 'cash',
      note: '',
    })).toThrow(/use PHP/i);
    expect(() => parsePaymentActionWrite({ action: 'recordRefund' }))
      .toThrow(/refund amount/i);
    expect(parsePaymentActionWrite({
      action: 'confirmRefund',
      amountMinor: 10_000,
      note: '',
    })).toMatchObject({ amountMinor: 10_000 });
  });

  it('hashes structured documents and requires dispute evidence linkage', () => {
    const document = parseDocumentWrite({
      clientReference: 'document-1',
      documentType: 'serviceReport',
      title: 'Service report',
      content: 'Charging port replaced and tested.',
    });
    expect(contentDigest(document.content)).toMatch(/^[a-f0-9]{64}$/);
    expect(utf8Bytes('🙂')).toBe(4);
    expect(() => parseDocumentWrite({
      clientReference: 'document-2',
      documentType: 'disputeEvidence',
      title: 'Evidence note',
      content: 'Inspection details.',
    })).toThrow(/linked to a dispute/i);
  });

  it('validates dispute summaries and deterministic resolution states', () => {
    expect(parseDisputeWrite({
      clientReference: 'dispute-1',
      reasonCode: 'workQuality',
      summary: 'The repaired device still does not charge consistently.',
      requestedOutcome: 'continueService',
    })).toMatchObject({ reasonCode: 'workQuality' });
    expect(parseDisputeResolutionWrite({
      outcome: 'fullRefund',
      note: 'Both participants supplied enough evidence for this resolution.',
    })).toMatchObject({ outcome: 'fullRefund' });
    expect(targetStatusForDisputeOutcome('serviceCompleted')).toBe('completed');
    expect(targetStatusForDisputeOutcome('fullRefund')).toBe('cancelled');
    expect(targetStatusForDisputeOutcome('serviceContinues')).toBe('inProgress');
  });
});

describe('transaction toolbox database policy', () => {
  const migration13 = readFileSync(
    new URL('../migrations/0013_build20_1b_transaction_exceptions.sql', import.meta.url),
    'utf8',
  );
  const migration14 = readFileSync(
    new URL('../migrations/0014_build21_payment_receipts.sql', import.meta.url),
    'utf8',
  );
  const migration15 = readFileSync(
    new URL('../migrations/0015_documents_and_disputes.sql', import.meta.url),
    'utf8',
  );

  it('uses participant-scoped RLS and one pending mutual decision', () => {
    expect(migration13).toContain('hdc_is_transaction_participant');
    expect(migration13).toContain('hdc_schedule_one_pending_per_transaction');
    expect(migration13).toContain('hdc_change_order_one_pending_per_transaction');
    expect(migration13).toMatch(/ENABLE ROW LEVEL SECURITY/g);
  });

  it('labels receipts as participant confirmed rather than provider verified', () => {
    expect(migration14).toContain("verification_level = 'participantConfirmed'");
    expect(migration14).not.toContain('providerVerified');
    expect(migration14).toContain('related_event_id');
  });

  it('permits one active dispute and immutable case events', () => {
    expect(migration15).toContain('hdc_service_disputes_one_active');
    expect(migration15).toContain("status IN ('open', 'underReview')");
    expect(migration15).toContain("event_type IN (");
    expect(migration15).not.toContain(
      'GRANT SELECT, INSERT, UPDATE ON public.hdc_service_dispute_events',
    );
  });
});
