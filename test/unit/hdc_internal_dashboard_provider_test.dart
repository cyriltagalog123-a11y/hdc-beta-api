import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/providers/hdc_internal_dashboard_provider.dart';

const _timestamp = '2026-08-21T10:00:00.000Z';

AccountIdentity _identity({
  Set<HDCInternalRole> internalRoles = const {HDCInternalRole.owner},
}) {
  final now = DateTime(2026, 8, 21);
  return AccountIdentity(
    id: 'user-1',
    email: 'person@example.com',
    displayName: 'HDC Person',
    status: HDCAccountStatus.active,
    platformRoles: const {HDCPlatformRole.customer},
    internalRoles: internalRoles,
    createdAt: now,
    updatedAt: now,
  );
}

Future<MemoryAuthSessionStore> _sessionStore() async {
  final store = MemoryAuthSessionStore();
  await store.write(
    StoredAuthSession(
      token: 'private-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  );
  return store;
}

void main() {
  test('private dashboard loads only the authorized response', () async {
    final store = await _sessionStore();
    var networkCalls = 0;
    final provider = HdcInternalDashboardProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((request) async {
          networkCalls += 1;
          expect(request.url.path, '/api/internal/dashboard');
          expect(request.headers['authorization'], 'Bearer private-token');
          return http.Response(
            jsonEncode({
              'privateWorkspace': true,
              'account': {
                'userId': 'user-1',
                'displayName': 'HDC Person',
              },
              'permissions': {
                'canApprovePlatformRoles': true,
                'canReviewAccountRecovery': true,
                'canManageInternalStructure': true,
                'hasPrivilegedResourceAccess': true,
                'canModerateCommunity': true,
              },
              'statistics': {
                'myAssignments': 1,
                'pendingRoleApplications': 2,
                'activeDepartments': 3,
                'activeSections': 4,
                'activeStaffAssignments': 5,
                'activeMembers': 6,
                'openServiceRequests': 7,
                'activeServiceTransactions': 8,
              },
              'assignments': [
                {
                  'id': 'assignment-1',
                  'title': 'Operations Lead',
                  'departmentCode': 'operations',
                  'departmentName': 'Operations',
                  'sectionCode': 'support',
                  'sectionName': 'Support',
                  'createdAt': _timestamp,
                  'updatedAt': _timestamp,
                },
              ],
              'recentActivities': [
                {
                  'eventType': 'roles.application_approved',
                  'eventStatus': 'success',
                  'createdAt': _timestamp,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    provider.bindIdentity(_identity());
    await pumpEventQueue(times: 20);
    expect(networkCalls, 0);
    await provider.refresh();

    expect(networkCalls, 1);
    expect(provider.hasAccess, isTrue);
    expect(provider.snapshot?.userId, 'user-1');
    expect(provider.permissions.canApprovePlatformRoles, isTrue);
    expect(provider.statistics['activeMembers'], 6);
    expect(provider.assignments.single.departmentName, 'Operations');
    expect(provider.recentActivities.single.eventStatus, 'success');
    provider.dispose();
  });

  test('ordinary account cannot load the private dashboard', () async {
    final store = await _sessionStore();
    var networkCalls = 0;
    final provider = HdcInternalDashboardProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((request) async {
          networkCalls += 1;
          return http.Response('{}', 500);
        }),
      ),
    );

    provider.bindIdentity(
      _identity(internalRoles: const <HDCInternalRole>{}),
    );
    await pumpEventQueue(times: 20);
    await provider.refresh();

    expect(provider.hasAccess, isFalse);
    expect(provider.snapshot, isNull);
    expect(networkCalls, 0);
    provider.dispose();
  });
}
