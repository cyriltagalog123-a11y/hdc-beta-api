import 'package:flutter_test/flutter_test.dart';

import 'package:hdc_app/core/proposals/customer_offer_catalog.dart';
import 'package:hdc_app/models/proposal.dart';
import 'package:hdc_app/models/service_request.dart';

ServiceRequest _request({required String id, required String customerId}) {
  return ServiceRequest.fromJson({
    'id': id,
    'customerId': customerId,
    'customerName': customerId,
    'title': 'Laptop issue $id',
    'categoryId': 'laptop-repair',
    'categoryName': 'Laptop Repair',
    'description': 'The laptop does not start.',
    'location': 'Cebu City',
    'preferredDate': '2026-08-30T09:00:00.000Z',
    'preferredTime': '9:00 AM',
    'urgency': 'normal',
    'minimumBudget': 500,
    'maximumBudget': 1500,
    'status': 'receivingOffers',
    'offerCount': 1,
    'createdAt': '2026-08-20T08:00:00.000Z',
    'updatedAt': '2026-08-20T08:00:00.000Z',
  });
}

Proposal _proposal({
  required String id,
  required String requestId,
  required ProposalStatus status,
  required String updatedAt,
}) {
  return Proposal.fromJson({
    'id': id,
    'requestId': requestId,
    'technicianId': 'technician-$id',
    'status': status.name,
    'serviceFee': 1000,
    'partsArrangement': 'none',
    'estimatedPartsCost': null,
    'earliestArrival': '2026-08-30T10:00:00.000Z',
    'estimatedDurationMinutes': 60,
    'warrantyType': 'thirtyDays',
    'customWarrantyDays': null,
    'diagnosis': 'Likely power delivery issue requiring inspection.',
    'repairApproach': 'Inspect the charger, battery, and power components.',
    'professionalNotes': 'Final diagnosis follows physical inspection.',
    'reputation': {
      'technicianName': 'Technician $id',
      'isVerified': true,
      'rating': 4.8,
      'completedJobs': 20,
      'averageResponseMinutes': 10,
      'successRate': 95,
      'memberSinceYear': 2024,
    },
    'qualityScore': 85,
    'attachmentIds': <String>[],
    'createdAt': '2026-08-21T08:00:00.000Z',
    'updatedAt': updatedAt,
    'submittedAt': status == ProposalStatus.draft
        ? null
        : '2026-08-21T08:30:00.000Z',
    'viewedAt': null,
    'shortlistedAt': null,
    'acceptedAt': status == ProposalStatus.accepted ? updatedAt : null,
    'declinedAt': null,
    'expiredAt': null,
    'withdrawnAt': status == ProposalStatus.withdrawn ? updatedAt : null,
  });
}

void main() {
  test('catalog returns all visible offers across the customer requests', () {
    final entries = const CustomerOfferCatalog().entriesFor(
      customerId: 'customer-a',
      requests: [
        _request(id: 'SR-A1', customerId: 'customer-a'),
        _request(id: 'SR-A2', customerId: 'customer-a'),
        _request(id: 'SR-B1', customerId: 'customer-b'),
      ],
      proposals: [
        _proposal(
          id: 'PR-OLD',
          requestId: 'SR-A1',
          status: ProposalStatus.submitted,
          updatedAt: '2026-08-21T09:00:00.000Z',
        ),
        _proposal(
          id: 'PR-NEW',
          requestId: 'SR-A2',
          status: ProposalStatus.accepted,
          updatedAt: '2026-08-21T11:00:00.000Z',
        ),
        _proposal(
          id: 'PR-DRAFT',
          requestId: 'SR-A1',
          status: ProposalStatus.draft,
          updatedAt: '2026-08-21T12:00:00.000Z',
        ),
        _proposal(
          id: 'PR-WITHDRAWN',
          requestId: 'SR-A1',
          status: ProposalStatus.withdrawn,
          updatedAt: '2026-08-21T13:00:00.000Z',
        ),
        _proposal(
          id: 'PR-OTHER-CUSTOMER',
          requestId: 'SR-B1',
          status: ProposalStatus.submitted,
          updatedAt: '2026-08-21T14:00:00.000Z',
        ),
      ],
    );

    expect(
      entries.map((entry) => entry.proposal.id),
      ['PR-NEW', 'PR-OLD'],
    );
    expect(
      entries.map((entry) => entry.request.id),
      ['SR-A2', 'SR-A1'],
    );
  });
}
