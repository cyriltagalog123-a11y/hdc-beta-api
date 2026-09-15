import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/features/profiles/role_profile_edit_screen.dart';
import 'package:hdc_app/features/search/public_technician_profile_screen.dart';
import 'package:hdc_app/features/search/search_screen.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/models/service_request_draft.dart';
import 'package:hdc_app/providers/hdc_profile_provider.dart';
import 'package:hdc_app/providers/technician_discovery_provider.dart';

Map<String, Object?> _technician() => {
  'profileId': 'public-tech', 'publicMemberId': 'HDC-PUBLIC-TECH',
  'publicName': 'Jamie Repairs', 'contactEmail': 'shared@example.test',
  'details': {'yearsExperience': 5},
  'ratingCount': 1, 'averageRating': 4.0, 'completedServices': 2,
};

void _screenSize(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('guest opens public profile at width $width and refresh removes unavailable details', (tester) async {
      _screenSize(tester, width);
      var available = true;
      final discovery = TechnicianDiscoveryProvider(client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'), sessionStore: MemoryAuthSessionStore(),
        client: MockClient((request) async {
          expect(request.headers['authorization'], isNull);
          if (!available) {
            return http.Response('{"error":"technician_profile_not_found"}', 404);
          }
          if (request.url.path == '/api/discovery/technicians') {
            return http.Response(jsonEncode({'technicians': [_technician()]}), 200);
          }
          return http.Response(jsonEncode({
            'technician': _technician(), 'reviewPage': 0, 'hasMoreReviews': false,
            'reviews': [{'publicRatingId': 'HDC-RATE-ONE', 'score': 4,
              'review': 'Clear repair explanation and a working laptop.', 'createdAt': '2026-09-15T00:00:00Z'}],
          }), 200);
        }),
      ));
      final profiles = HdcProfileProvider();
      addTearDown(discovery.dispose);
      addTearDown(profiles.dispose);
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider.value(value: discovery),
        ChangeNotifierProvider.value(value: profiles),
      ], child: MaterialApp(home: SearchScreen(draft: ServiceRequestDraft()))));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('View Profile').hitTestable(), 350, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(PublicTechnicianProfileScreen), findsOneWidget);
      expect(find.text('Jamie Repairs'), findsOneWidget);
      expect(find.text('4.0 / 5 · 1 rating'), findsOneWidget);
      expect(find.textContaining('5 years experience'), findsOneWidget);
      expect(find.text('shared@example.test'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Clear repair explanation and a working laptop.'), 250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Clear repair explanation and a working laptop.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      available = false;
      await tester.tap(find.byTooltip('Refresh public profile'));
      await tester.pumpAndSettle();
      expect(find.text('Jamie Repairs'), findsNothing);
      expect(find.text('shared@example.test'), findsNothing);
      expect(find.textContaining('public profile is unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('technician saves selected visibility without erasing private details and form closes on account change', (tester) async {
    _screenSize(tester, 320);
    final store = MemoryAuthSessionStore();
    await store.write(StoredAuthSession(token: 'profile-token', expiresAt: DateTime.now().add(const Duration(hours: 1))));
    Map<String, dynamic>? saved;
    final roleProfile = <String, Object?>{
      'id': 'profile-one', 'userId': 'member-one', 'role': 'technician',
      'publicName': 'Jamie Repairs', 'contactEmail': 'private-contact@example.test',
      'details': {'yearsExperience': 5, 'publicFields': []},
    };
    final profiles = HdcProfileProvider(client: HdcWorkflowApiClient(
      baseUri: Uri.parse('https://example.test'), sessionStore: store,
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'roleProfile': {...roleProfile, ...saved!}}), 200);
        }
        return http.Response(jsonEncode({
          'memberProfile': {'userId': 'member-one', 'displayName': 'Jamie', 'email': 'account@example.test'},
          'roleProfiles': [roleProfile],
        }), 200);
      }),
    ));
    addTearDown(profiles.dispose);
    profiles.bindIdentity(AccountIdentity(
      id: 'member-one', displayName: 'Jamie', status: HDCAccountStatus.active,
      platformRoles: const {HDCPlatformRole.technician}, createdAt: DateTime(2026), updatedAt: DateTime(2026),
    ));
    await tester.pumpWidget(ChangeNotifierProvider.value(value: profiles,
      child: const MaterialApp(home: Scaffold(body: Text('Profile home')))));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const RoleProfileEditScreen(role: HDCPlatformRole.technician)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('hdc-public-field-contactEmail')), 500, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('hdc-public-field-contactEmail')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Save Technician Profile'), 400, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save Technician Profile'));
    await tester.pumpAndSettle();
    expect(saved?['contactEmail'], 'private-contact@example.test');
    expect((saved?['details'] as Map)['publicFields'], ['contactEmail']);
    expect(saved?['isPublic'], isTrue);
    expect(tester.takeException(), isNull);

    navigator.push(MaterialPageRoute<void>(builder: (_) => const RoleProfileEditScreen(role: HDCPlatformRole.technician)));
    await tester.pumpAndSettle();
    profiles.bindIdentity(null);
    await tester.pumpAndSettle();
    expect(find.textContaining('no longer available to this account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Save Technician Profile'), findsNothing);
  });
}
