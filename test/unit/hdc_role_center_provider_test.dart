import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/models/platform_role_application.dart';
import 'package:hdc_app/providers/hdc_role_center_provider.dart';

Map<String, Object?> _application({
  String id = 'application-1',
  String role = 'technician',
  String status = 'pending',
}) {
  return {
    'id': id,
    'userId': 'user-1',
    'role': role,
    'status': status,
    'applicantNote': 'Role request',
    'reviewNote': '',
    'reviewedBy': null,
    'reviewedAt': null,
    'createdAt': '2026-08-21T10:00:00.000Z',
    'updatedAt': '2026-08-21T10:00:00.000Z',
  };
}

AccountIdentity _identity() {
  final now = DateTime(2026, 8, 21);
  return AccountIdentity(
    id: 'user-1',
    email: 'person@example.com',
    displayName: 'HDC Person',
    status: HDCAccountStatus.active,
    platformRoles: const {HDCPlatformRole.customer},
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('Role Center consumes a platform-only public response', () async {
    final sessionStore = MemoryAuthSessionStore();
    await sessionStore.write(
      StoredAuthSession(
        token: 'role-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    final httpClient = MockClient((request) async {
      expect(request.url.path, '/api/roles/overview');
      expect(request.headers['authorization'], 'Bearer role-token');
      return http.Response(
        jsonEncode({
          'platformRoles': ['customer', 'supplier'],
          'applications': [_application(role: 'supplier', status: 'approved')],
          'notifications': [
            {
              'id': 'notification-1',
              'eventType': 'roles.application_approved',
              'priority': 'high',
              'title': 'Platform role approved',
              'message': 'Your supplier platform role is active.',
              'metadata': {'platformRole': 'supplier'},
              'readAt': null,
              'createdAt': '2026-08-21T10:05:00.000Z',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final provider = HdcRoleCenterProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: sessionStore,
        client: httpClient,
      ),
    );

    provider.bindIdentity(_identity());
    await pumpEventQueue(times: 20);

    expect(provider.platformRoles, {
      HDCPlatformRole.customer,
      HDCPlatformRole.supplier,
    });
    expect(provider.notifications.single.priority, 'high');
    expect(
      provider.latestApplicationFor(HDCPlatformRole.supplier)?.status,
      HDCPlatformRoleApplicationStatus.approved,
    );

    provider.dispose();
  });

  test('Role Center submits only the requested platform role', () async {
    final sessionStore = MemoryAuthSessionStore();
    await sessionStore.write(
      StoredAuthSession(
        token: 'role-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    var postSeen = false;
    final httpClient = MockClient((request) async {
      if (request.url.path == '/api/roles/overview') {
        return http.Response(
          jsonEncode({
            'platformRoles': ['customer'],
            'applications': <Object?>[],
            'notifications': <Object?>[],
          }),
          200,
        );
      }
      expect(request.url.path, '/api/role-applications');
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['role'], 'technician');
      expect(body['answers'], isA<Map<String, dynamic>>());
      expect(
        (body['answers'] as Map<String, dynamic>)['yearsExperience'],
        5,
      );
      expect(body.containsKey('internalRole'), isFalse);
      postSeen = true;
      return http.Response(
        jsonEncode({'application': _application()}),
        201,
      );
    });
    final provider = HdcRoleCenterProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: sessionStore,
        client: httpClient,
      ),
    );

    provider.bindIdentity(_identity());
    await pumpEventQueue(times: 20);
    await provider.applyForRole(
      HDCPlatformRole.technician,
      answers: const {
        'primarySpecialty': 'Computer repair',
        'yearsExperience': 5,
        'serviceArea': 'Metro Manila',
        'certifications': '',
        'portfolioUrl': '',
        'validIdentificationConfirmed': true,
        'backgroundCheckConsent': true,
        'phone': '+63 900 000 0000',
        'country': 'Philippines',
        'city': 'Manila',
        'reason':
            'I want to provide reliable technical support to HDC members.',
        'evidenceUrl': '',
        'agreedToPlatformStandards': true,
      },
      note: 'Role request',
    );

    expect(postSeen, isTrue);
    expect(
      provider.latestApplicationFor(HDCPlatformRole.technician)?.isPending,
      isTrue,
    );

    provider.dispose();
  });
}
