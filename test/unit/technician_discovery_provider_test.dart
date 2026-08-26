import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/providers/technician_discovery_provider.dart';

const _timestamp = '2026-08-26T12:09:19.018Z';

Map<String, Object?> _technician({
  required String id,
  required String name,
  required String location,
  List<String> skills = const [],
}) => {
  'profileId': id,
  'publicMemberId': 'HDC-${id.toUpperCase()}',
  'publicName': name,
  'headline': 'Device technician',
  'description': 'Repairs computers and mobile devices.',
  'location': location,
  'contactEmail': '',
  'contactPhone': '',
  'website': '',
  'details': {
    'skills': skills,
    'specialties': <String>[],
    'yearsExperience': 4,
    'serviceRadiusKm': 20,
    'availability': 'Weekdays',
    'emergencyService': false,
  },
  'updatedAt': _timestamp,
};

Map<String, Object?> _request() => {
  'id': 'SR-LIVE-1',
  'customerId': 'customer-1',
  'customerName': 'Cyril',
  'title': 'Laptop will not start',
  'categoryId': 'laptop-repair',
  'categoryName': 'Laptop Repair',
  'description': 'Laptop needs diagnostics.',
  'location': 'Cebu City',
  'preferredDate': '2026-08-27T08:00:00.000Z',
  'preferredTime': 'Any time',
  'urgency': 'normal',
  'minimumBudget': null,
  'maximumBudget': null,
  'status': 'open',
  'offerCount': 0,
  'createdAt': _timestamp,
  'updatedAt': _timestamp,
};

AccountIdentity _identity() => AccountIdentity(
  id: 'technician-1',
  email: 'tech@example.test',
  displayName: 'Technician',
  status: HDCAccountStatus.active,
  platformRoles: const {HDCPlatformRole.customer, HDCPlatformRole.technician},
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 20),
);

Future<MemoryAuthSessionStore> _sessionStore() async {
  final store = MemoryAuthSessionStore();
  await store.write(
    StoredAuthSession(
      token: 'discovery-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  );
  return store;
}

void main() {
  test('loads live directory and explicit technician opportunities', () async {
    final store = await _sessionStore();
    final requestedPaths = <String>[];
    final provider = TechnicianDiscoveryProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((request) async {
          requestedPaths.add(request.url.path);
          expect(request.headers['authorization'], 'Bearer discovery-token');
          if (request.url.path == '/api/discovery/technicians') {
            return http.Response(
              jsonEncode({
                'technicians': [
                  _technician(
                    id: 'cebu-tech',
                    name: 'Cebu Device Lab',
                    location: 'Cebu City',
                    skills: ['Laptop repair'],
                  ),
                ],
                'updatedAt': _timestamp,
              }),
              200,
            );
          }
          if (request.url.path == '/api/discovery/opportunities') {
            return http.Response(
              jsonEncode({
                'serviceRequests': [_request()],
                'updatedAt': _timestamp,
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      ),
    );

    provider.bindIdentity(_identity());
    await pumpEventQueue(times: 30);

    expect(requestedPaths, contains('/api/discovery/technicians'));
    expect(requestedPaths, contains('/api/discovery/opportunities'));
    expect(provider.technicians.single.publicName, 'Cebu Device Lab');
    expect(provider.opportunities.single.id, 'SR-LIVE-1');
    expect(provider.directoryError, isNull);
    expect(provider.opportunitiesError, isNull);
    provider.dispose();
  });

  test('manual search and requested area prioritize useful matches', () async {
    final store = await _sessionStore();
    final provider = TechnicianDiscoveryProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((request) async {
          if (request.url.path == '/api/discovery/technicians') {
            return http.Response(
              jsonEncode({
                'technicians': [
                  _technician(
                    id: 'manila-tech',
                    name: 'Metro Repair',
                    location: 'Manila City',
                    skills: ['Networking'],
                  ),
                  _technician(
                    id: 'cebu-tech',
                    name: 'Cebu Device Lab',
                    location: 'Cebu City',
                    skills: ['Laptop repair'],
                  ),
                ],
                'updatedAt': _timestamp,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'serviceRequests': <Object?>[],
              'updatedAt': _timestamp,
            }),
            200,
          );
        }),
      ),
    );

    provider.bindIdentity(_identity());
    await pumpEventQueue(times: 30);

    expect(
      provider
          .searchTechnicians(serviceArea: 'Cebu City')
          .map((value) => value.publicName),
      <String>['Cebu Device Lab', 'Metro Repair'],
    );
    expect(
      provider.searchTechnicians(query: 'laptop').single.publicName,
      'Cebu Device Lab',
    );
    provider.dispose();
  });
}
