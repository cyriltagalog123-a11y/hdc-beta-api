import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/models/proposal.dart';
import 'package:hdc_app/models/service_request.dart';
import 'package:hdc_app/repositories/hdc_api_workflow_repositories.dart';

Map<String, Object?> _request(String status) {
  return {
    'id': 'SR-1720000000000',
    'customerId': 'customer-123',
    'customerName': 'HDC Customer',
    'title': 'Repair a laptop charging port',
    'categoryId': 'laptop-repair',
    'categoryName': 'Laptop Repair',
    'description': 'The USB-C charging port no longer detects the charger.',
    'location': 'Cebu City',
    'preferredDate': '2026-08-25T09:00:00.000Z',
    'preferredTime': '9:00 AM',
    'urgency': 'normal',
    'minimumBudget': 800,
    'maximumBudget': 2000,
    'status': status,
    'offerCount': 1,
    'createdAt': '2026-08-21T08:00:00.000Z',
    'updatedAt': '2026-08-21T09:00:00.000Z',
  };
}

Map<String, Object?> _proposal(String status) {
  return {
    'id': 'PR-1720000000000',
    'requestId': 'SR-1720000000000',
    'technicianId': 'technician-123',
    'status': status,
    'serviceFee': 1200,
    'partsArrangement': 'technicianSupplies',
    'estimatedPartsCost': 350,
    'earliestArrival': '2026-08-25T10:00:00.000Z',
    'estimatedDurationMinutes': 120,
    'warrantyType': 'thirtyDays',
    'customWarrantyDays': null,
    'diagnosis': 'The charging port may have cracked solder joints.',
    'repairApproach': 'Inspect and repair or replace the USB-C connector.',
    'professionalNotes': 'Final parts cost depends on inspection.',
    'reputation': {
      'technicianName': 'HDC Technician',
      'isVerified': false,
      'rating': 0,
      'completedJobs': 0,
      'averageResponseMinutes': 0,
      'successRate': 0,
      'memberSinceYear': 2026,
    },
    'qualityScore': 80,
    'attachmentIds': <String>[],
    'createdAt': '2026-08-21T08:30:00.000Z',
    'updatedAt': '2026-08-21T09:00:00.000Z',
    'submittedAt': '2026-08-21T08:45:00.000Z',
    'viewedAt': null,
    'shortlistedAt': null,
    'acceptedAt': null,
    'declinedAt': status == 'declined'
        ? '2026-08-21T10:00:00.000Z'
        : null,
    'expiredAt': null,
    'withdrawnAt': null,
  };
}

void main() {
  test('request cancellation applies canonical related proposal state', () async {
    final sessionStore = MemoryAuthSessionStore();
    await sessionStore.write(
      StoredAuthSession(
        token: 'opaque-workflow-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/workflow/bootstrap') {
        return http.Response(
          jsonEncode({
            'serviceRequests': [_request('receivingOffers')],
            'proposals': [_proposal('submitted')],
            'transactionSeeds': <Object?>[],
            'serviceTransactions': <Object?>[],
          }),
          200,
        );
      }
      if (request.method == 'PUT' &&
          request.url.path == '/api/service-requests/SR-1720000000000') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['status'], 'cancelled');
        return http.Response(
          jsonEncode({
            'serviceRequest': _request('cancelled'),
            'updatedProposals': [_proposal('declined')],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final store = HdcApiWorkflowStore(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: sessionStore,
        client: httpClient,
      ),
    );
    store.bindUser('11111111-1111-4111-8111-111111111111');
    var notifications = 0;
    store.addListener(() => notifications += 1);

    await store.refresh();
    final current = store.serviceRequests.single;
    await store.updateServiceRequest(
      current.copyWith(status: ServiceRequestStatus.cancelled),
    );

    expect(store.serviceRequests.single.status, ServiceRequestStatus.cancelled);
    expect(store.proposals.single.status, ProposalStatus.declined);
    expect(notifications, 2);
    store.dispose();
  });

  test('late bootstrap response cannot replace a newly bound account', () async {
    final sessionStore = MemoryAuthSessionStore();
    await sessionStore.write(
      StoredAuthSession(
        token: 'opaque-workflow-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    final accountAResponse = Completer<http.Response>();
    var callCount = 0;
    final httpClient = MockClient((request) async {
      expect(request.url.path, '/api/workflow/bootstrap');
      callCount += 1;
      if (callCount == 1) return accountAResponse.future;
      return http.Response(
        jsonEncode({
          'serviceRequests': [
            {
              ..._request('open'),
              'id': 'SR-ACCOUNT-B',
              'customerId': '22222222-2222-4222-8222-222222222222',
              'title': 'Account B request',
              'offerCount': 0,
            },
          ],
          'proposals': <Object?>[],
          'transactionSeeds': <Object?>[],
          'serviceTransactions': <Object?>[],
        }),
        200,
      );
    });
    final store = HdcApiWorkflowStore(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: sessionStore,
        client: httpClient,
      ),
    );

    store.bindUser('11111111-1111-4111-8111-111111111111');
    final accountARefresh = store.refresh();
    await Future<void>.delayed(Duration.zero);

    store.bindUser('22222222-2222-4222-8222-222222222222');
    await store.refresh();
    expect(store.serviceRequests.single.id, 'SR-ACCOUNT-B');

    accountAResponse.complete(
      http.Response(
        jsonEncode({
          'serviceRequests': [
            {
              ..._request('open'),
              'id': 'SR-ACCOUNT-A',
              'customerId': '11111111-1111-4111-8111-111111111111',
              'title': 'Account A request',
              'offerCount': 0,
            },
          ],
          'proposals': <Object?>[],
          'transactionSeeds': <Object?>[],
          'serviceTransactions': <Object?>[],
        }),
        200,
      ),
    );
    await accountARefresh;

    expect(store.serviceRequests.single.id, 'SR-ACCOUNT-B');
    expect(callCount, 2);
    store.dispose();
  });
}
