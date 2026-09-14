import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/features/internal/operations_report_screen.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/providers/hdc_internal_dashboard_provider.dart';

AccountIdentity _owner() => AccountIdentity(
  id: 'owner', displayName: 'Owner', status: HDCAccountStatus.active,
  platformRoles: const {HDCPlatformRole.customer}, internalRoles: const {HDCInternalRole.owner},
  createdAt: DateTime(2026), updatedAt: DateTime(2026),
);

Map<String, Object?> _report({String userId = 'owner', bool detail = false}) => {
  'privateWorkspace': true, 'userId': userId, 'report': 'activeMembers',
  'title': 'Registered members', 'description': 'Active accounts are enabled, not necessarily online.',
  'total': 1, 'offset': 0, 'limit': 25, 'hasMore': false, 'generatedAt': '2026-09-10T10:00:00Z',
  'records': [{
    'id': 'member-1', 'title': 'Jamie Member', 'subtitle': 'HDC-MEMBER-01', 'status': 'active',
    'created_at': '2026-09-01T10:00:00Z', 'updated_at': '2026-09-10T10:00:00Z',
    'data': detail ? {'Email': 'private-member@example.test', 'Member ID': 'HDC-MEMBER-01'} : <String, Object?>{},
  }],
  'sections': <Object?>[],
};

Future<HdcInternalDashboardProvider> _provider(Future<http.Response> Function(http.Request) send) async {
  final store = MemoryAuthSessionStore();
  await store.write(StoredAuthSession(token: 'test-token', expiresAt: DateTime.now().add(const Duration(hours: 1))));
  return HdcInternalDashboardProvider(client: HdcWorkflowApiClient(
    baseUri: Uri.parse('https://example.test'), sessionStore: store, client: MockClient(send),
  ))..bindIdentity(_owner());
}

void main() {
  testWidgets('compact report opens a member detail and removes it on account change', (tester) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await _provider((request) async {
      expect(request.url.path, '/api/internal/reports');
      return http.Response(jsonEncode(_report(detail: request.url.queryParameters.containsKey('id'))), 200);
    });
    addTearDown(provider.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: provider,
      child: const MaterialApp(home: OperationsReportScreen(reportKey: 'activeMembers'))));
    await tester.pumpAndSettle();
    expect(find.text('1 matching records'), findsOneWidget);
    expect(find.text('private-member@example.test'), findsNothing);
    await tester.tap(find.text('Jamie Member'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('private-member@example.test'),
      220,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.text('private-member@example.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
    provider.bindIdentity(null);
    await tester.pumpAndSettle();
    expect(find.text('private-member@example.test'), findsNothing);
    expect(find.textContaining('Your account or permissions changed'), findsOneWidget);
  });

  test('reports reject mismatched account responses and pending results after logout', () async {
    final provider = await _provider((_) async => http.Response(jsonEncode(_report(userId: 'other')), 200));
    await expectLater(provider.loadReport(report: 'activeMembers'),
      throwsA(isA<HdcWorkflowException>().having((e) => e.code, 'code', 'invalid_server_response')));
    provider.dispose();
    final pending = Completer<http.Response>();
    final delayed = await _provider((_) => pending.future);
    final result = delayed.loadReport(report: 'activeMembers');
    final rejected = expectLater(result, throwsA(isA<HdcWorkflowException>()
      .having((e) => e.code, 'code', 'operations_request_stale')));
    delayed.bindIdentity(null);
    pending.complete(http.Response(jsonEncode(_report()), 200));
    await rejected;
    delayed.dispose();
  });
}
