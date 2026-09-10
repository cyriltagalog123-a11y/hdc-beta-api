import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/features/profiles/role_profile_preview_screen.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/providers/hdc_profile_provider.dart';

void main() {
  testWidgets('role preview keeps account email private and closes on logout', (tester) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryAuthSessionStore();
    await store.write(StoredAuthSession(token: 'profile-token', expiresAt: DateTime.now().add(const Duration(hours: 1))));
    final profiles = HdcProfileProvider(client: HdcWorkflowApiClient(
      baseUri: Uri.parse('https://example.test'), sessionStore: store,
      client: MockClient((_) async => http.Response(jsonEncode({
        'memberProfile': {'userId': 'member', 'displayName': 'Jamie', 'email': 'private-login@example.test'},
        'roleProfiles': [{
          'id': 'role-profile', 'userId': 'member', 'role': 'customer', 'publicName': 'Jamie Public',
          'headline': 'Local customer', 'description': 'My role introduction',
          'contactEmail': 'public-contact@example.test', 'isPublic': false,
        }],
      }), 200)),
    ));
    addTearDown(profiles.dispose);
    profiles.bindIdentity(AccountIdentity(
      id: 'member', displayName: 'Jamie', status: HDCAccountStatus.active,
      platformRoles: const {HDCPlatformRole.customer}, createdAt: DateTime(2026), updatedAt: DateTime(2026),
    ));
    await tester.pumpWidget(ChangeNotifierProvider.value(value: profiles,
      child: const MaterialApp(home: RoleProfilePreviewScreen(role: HDCPlatformRole.customer, userId: 'member'))));
    await tester.pumpAndSettle();
    expect(find.text('Jamie Public'), findsOneWidget);
    expect(find.text('public-contact@example.test'), findsOneWidget);
    expect(find.text('private-login@example.test'), findsNothing);
    expect(find.textContaining('Private role profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
    profiles.bindIdentity(null);
    await tester.pumpAndSettle();
    expect(find.text('Jamie Public'), findsNothing);
    expect(find.textContaining('no longer available'), findsOneWidget);
  });
}
