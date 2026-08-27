import { describe, expect, it } from 'vitest';
import {
  canCustomerUpdateProposalStatus,
  canCustomerUpdateRequestStatus,
  canTechnicianUpdateProposalStatus,
  parseProposalWrite,
  parseServiceRequestWrite,
  proposalQualityScore,
  proposalWriteMatchesRow,
  serviceRequestWriteMatchesRow,
  technicianReputation,
  transactionTransition,
} from '../netlify/functions/_lib/workflow.mjs';

const validRequest = {
  id: 'SR-1720000000000',
  title: 'Repair a laptop charging port',
  categoryId: 'laptop-repair',
  categoryName: 'Laptop Repair',
  description: 'The USB-C charging port no longer detects the charger.',
  location: 'Cebu City',
  preferredDate: '2026-08-25T09:00:00.000Z',
  preferredTime: '9:00 AM',
  urgency: 'normal',
  minimumBudget: 800,
  maximumBudget: 2000,
  status: 'open',
};

const validProposal = {
  id: 'PR-1720000000000',
  requestId: validRequest.id,
  status: 'draft',
  serviceFee: 1200,
  partsArrangement: 'technicianSupplies',
  estimatedPartsCost: 350,
  earliestArrival: '2026-08-25T10:00:00.000Z',
  estimatedDurationMinutes: 120,
  warrantyType: 'thirtyDays',
  customWarrantyDays: null,
  diagnosis: 'The charging port may have cracked solder joints on the board.',
  repairApproach: 'Inspect the port, test the power rail, and resolder or replace the connector.',
  professionalNotes: 'Final parts cost depends on inspection.',
  attachmentIds: [],
  submittedAt: null,
  viewedAt: null,
  shortlistedAt: null,
  declinedAt: null,
  withdrawnAt: null,
};

describe('workflow input validation', () => {
  it('normalizes an HDC service request without accepting client identity fields', () => {
    const parsed = parseServiceRequestWrite({
      ...validRequest,
      customerId: 'forged-user',
      customerName: 'Forged Name',
      offerCount: 999,
    });
    expect(parsed.id).toBe(validRequest.id);
    expect(parsed).not.toHaveProperty('customerId');
    expect(parsed).not.toHaveProperty('offerCount');
  });

  it('rejects reversed request budgets', () => {
    expect(() => parseServiceRequestWrite({
      ...validRequest,
      minimumBudget: 3000,
      maximumBudget: 1000,
    })).toThrow(/minimumBudget/);
  });

  it('recognizes an exact service-request retry without trusting client identity', () => {
    const parsed = parseServiceRequestWrite(validRequest);
    expect(serviceRequestWriteMatchesRow({
      customer_id: 'customer-uuid',
      title: parsed.title,
      category_id: parsed.categoryId,
      category_name: parsed.categoryName,
      description: parsed.description,
      location: parsed.location,
      preferred_date: parsed.preferredDate,
      preferred_time: parsed.preferredTime,
      urgency: parsed.urgency,
      minimum_budget: '800.00',
      maximum_budget: '2000.00',
      status: parsed.status,
    }, parsed, 'customer-uuid')).toBe(true);
  });

  it('rejects a reused service-request identifier with different content', () => {
    const parsed = parseServiceRequestWrite(validRequest);
    expect(serviceRequestWriteMatchesRow({
      customer_id: 'customer-uuid',
      title: 'A different request',
      category_id: parsed.categoryId,
      category_name: parsed.categoryName,
      description: parsed.description,
      location: parsed.location,
      preferred_date: parsed.preferredDate,
      preferred_time: parsed.preferredTime,
      urgency: parsed.urgency,
      minimum_budget: parsed.minimumBudget,
      maximum_budget: parsed.maximumBudget,
      status: parsed.status,
    }, parsed, 'customer-uuid')).toBe(false);
  });

  it('requires parts cost to match technician-supplied parts', () => {
    expect(() => parseProposalWrite({
      ...validProposal,
      partsArrangement: 'customerSupplies',
    })).toThrow(/Parts cost/);
  });

  it('recomputes proposal quality on the server', () => {
    const proposal = parseProposalWrite(validProposal);
    expect(proposalQualityScore(proposal, new Date('2026-08-21T00:00:00.000Z')))
      .toBeGreaterThanOrEqual(40);
  });

  it('recognizes an exact proposal retry across a regenerated client id', () => {
    const parsed = parseProposalWrite(validProposal);
    const score = proposalQualityScore(parsed);
    expect(proposalWriteMatchesRow({
      id: 'PR-first-attempt',
      request_id: parsed.requestId,
      technician_id: 'technician-uuid',
      status: parsed.status,
      service_fee: '1200.00',
      parts_arrangement: parsed.partsArrangement,
      estimated_parts_cost: '350.00',
      earliest_arrival: parsed.earliestArrival,
      estimated_duration_minutes: parsed.estimatedDurationMinutes,
      warranty_type: parsed.warrantyType,
      custom_warranty_days: null,
      diagnosis: parsed.diagnosis,
      repair_approach: parsed.repairApproach,
      professional_notes: parsed.professionalNotes,
      quality_score: score,
      attachment_ids: [],
    }, {
      ...parsed,
      id: 'PR-retry-after-lost-response',
    }, 'technician-uuid', score)).toBe(true);
  });

  it('does not replay a conflicting proposal write', () => {
    const parsed = parseProposalWrite(validProposal);
    const score = proposalQualityScore(parsed);
    expect(proposalWriteMatchesRow({
      request_id: parsed.requestId,
      technician_id: 'technician-uuid',
      status: parsed.status,
      service_fee: '999.00',
      parts_arrangement: parsed.partsArrangement,
      estimated_parts_cost: parsed.estimatedPartsCost,
      earliest_arrival: parsed.earliestArrival,
      estimated_duration_minutes: parsed.estimatedDurationMinutes,
      warranty_type: parsed.warrantyType,
      custom_warranty_days: parsed.customWarrantyDays,
      diagnosis: parsed.diagnosis,
      repair_approach: parsed.repairApproach,
      professional_notes: parsed.professionalNotes,
      quality_score: score,
      attachment_ids: parsed.attachmentIds,
    }, parsed, 'technician-uuid', score)).toBe(false);
  });
});

describe('workflow authorization transitions', () => {
  it('only lets customers cancel editable requests', () => {
    expect(canCustomerUpdateRequestStatus('open', 'cancelled')).toBe(true);
    expect(canCustomerUpdateRequestStatus('inProgress', 'cancelled')).toBe(false);
  });

  it('keeps technician and customer proposal transitions distinct', () => {
    expect(canTechnicianUpdateProposalStatus('draft', 'submitted')).toBe(true);
    expect(canTechnicianUpdateProposalStatus('submitted', 'accepted')).toBe(false);
    expect(canCustomerUpdateProposalStatus('submitted', 'shortlisted')).toBe(true);
    expect(canCustomerUpdateProposalStatus('shortlisted', 'accepted')).toBe(false);
  });

  it('enforces participant-specific transaction transitions', () => {
    expect(transactionTransition('confirmed', 'scheduled', 'technician')).not.toBeNull();
    expect(transactionTransition('confirmed', 'scheduled', 'customer')).toBeNull();
    expect(
      transactionTransition(
        'awaitingCustomerConfirmation',
        'completed',
        'customer',
      ),
    ).toMatchObject({ requestStatus: 'completed' });
  });

  it('derives a neutral reputation snapshot from authenticated identity', () => {
    expect(technicianReputation({
      id: 'authenticated-tech-id',
      displayName: 'HDC Beta Technician',
      roles: ['technician'],
      createdAt: '2026-08-20T00:00:00.000Z',
    })).toEqual({
      technicianName: 'HDC Beta Technician',
      isVerified: false,
      rating: 0,
      completedJobs: 0,
      averageResponseMinutes: 0,
      successRate: 0,
      memberSinceYear: 2026,
    });
  });
});
