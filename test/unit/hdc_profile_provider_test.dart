import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/providers/hdc_profile_provider.dart';

const _timestamp = '2026-08-21T10:00:00.000Z';

Map<String, Object?> _memberProfile() => {
      'userId': 'user-1',
      'displayName': 'Jamie Cruz',
      'email': 'jamie@example.com',
      'bio': 'HDC member',
      'location': 'Manila',
      'avatarUrl': '',
      'contactPreference': 'in_app',
      'version': 1,
      'createdAt': _timestamp,
      'updatedAt': _timestamp,
    };

Map<String, Object?> _roleProfile(
  String role, {
  String? publicName,
  Map<String, Object?> details = const {},
}) =>
    {
      'id': 'profile-$role',
      'userId': 'user-1',
      'role': role,
      'publicName': publicName ?? 'Jamie Cruz',
      'headline': '',
      'description': '',
      'location': '',
      'contactEmail': '',
      'contactPhone': '',
      'website': '',
      'isPublic': false,
      'details': details,
      'version': 1,
      'createdAt': _timestamp,
      'updatedAt': _timestamp,
    };

Map<String, Object?> _overview() => {
      'account': {
        'id': 'user-1',
        'email': 'jamie@example.com',
        'displayName': 'Jamie Cruz',
      },
      'memberProfile': _memberProfile(),
      'roleProfiles': [
        _roleProfile('customer'),
        _roleProfile(
          'technician',
          publicName: 'Jamie Repairs',
          details: {
            'skills': ['Diagnostics'],
          },
        ),
      ],
    };

AccountIdentity _identity() {
  final now = DateTime(2026, 8, 21);
  return AccountIdentity(
    id: 'user-1',
    email: 'jamie@example.com',
    displayName: 'Jamie Cruz',
    status: HDCAccountStatus.active,
    platformRoles: const {
      HDCPlatformRole.customer,
      HDCPlatformRole.technician,
    },
    createdAt: now,
    updatedAt: now,
  );
}

Future<MemoryAuthSessionStore> _sessionStore() async {
  final store = MemoryAuthSessionStore();
  await store.write(
    StoredAuthSession(
      token: 'profile-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  );
  return store;
}

void main() {
  test('one account loads independent profiles for every active role', () async {
    final store = await _sessionStore();
    final provider = HdcProfileProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((request) async {
          expect(request.url.path, '/api/profiles');
          expect(request.headers['authorization'], 'Bearer profile-token');
          return http.Response(jsonEncode(_overview()), 200);
        }),
      ),
    );

    provider.bindIdentity(_identity());
    await pumpEventQueue(times: 20);

    expect(provider.memberProfile?.userId, 'user-1');
    expect(provider.profileFor(HDCPlatformRole.customer)?.userId, 'user-1');
    expect(
      provider.profileFor(HDCPlatformRole.technician)?.publicName,
      'Jamie Repairs',
    );
    expect(provider.selectedRole, HDCPlatformRole.customer);

    provider.selectRole(HDCPlatformRole.technician);
    expect(provider.selectedRole, HDCPlatformRole.technician);
    provider.dispose();
  });

  test('saving Technician changes only the Technician profile', () async {
    final store = await _sessionStore();
    Map<String, dynamic>? submitted;
    final provider = HdcProfileProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(jsonEncode(_overview()), 200);
          }
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/profiles/technician');
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'roleProfile': _roleProfile(
                'technician',
                publicName: 'JC Device Lab',
                details: {
                  'skills': ['Diagnostics', 'Soldering'],
                  'specialties': <String>[],
                  'yearsExperience': 8,
                  'serviceRadiusKm': 20,
                  'hourlyRate': 850,
                  'availability': 'Weekdays',
                  'emergencyService': false,
                },
              ),
            }),
            200,
          );
        }),
      ),
    );

    provider.bindIdentity(_identity());
    await pumpEventQueue(times: 20);
    await provider.saveRoleProfile(
      HDCPlatformRole.technician,
      body: {
        'publicName': 'JC Device Lab',
        'headline': 'Device technician',
        'description': '',
        'location': 'Manila',
        'contactEmail': '',
        'contactPhone': '',
        'website': '',
        'isPublic': false,
        'details': {
          'skills': ['Diagnostics', 'Soldering'],
          'specialties': <String>[],
          'yearsExperience': 8,
          'serviceRadiusKm': 20,
          'hourlyRate': 850,
          'availability': 'Weekdays',
          'emergencyService': false,
        },
      },
    );

    expect(submitted?['publicName'], 'JC Device Lab');
    expect(provider.memberProfile?.displayName, 'Jamie Cruz');
    expect(
      provider.profileFor(HDCPlatformRole.customer)?.publicName,
      'Jamie Cruz',
    );
    expect(
      provider.profileFor(HDCPlatformRole.technician)?.publicName,
      'JC Device Lab',
    );
    provider.dispose();
  });
}
