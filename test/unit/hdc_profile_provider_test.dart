import 'dart:async';
import 'dart:convert';

import 'package:hdc_app/models/hdc_profile.dart';

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
  test('member essentials do not require an optional photo', () {
    final member = HDCMemberProfile.fromJson(_memberProfile());
    expect(member.avatarUrl, isEmpty);
    expect(member.completionPercent, 100);
    expect(member.missingEssentials, isEmpty);
    expect(HDCMemberProfile.fromJson({..._memberProfile(), 'bio': ''}).missingEssentials, ['About you']);
  });

  test('profile reads and writes reject another account or role', () async {
    final store = await _sessionStore();
    final provider = HdcProfileProvider(client: HdcWorkflowApiClient(
      baseUri: Uri.parse('https://example.test'), sessionStore: store,
      client: MockClient((request) async => http.Response(jsonEncode(
        request.method == 'GET'
          ? {..._overview(), 'memberProfile': {..._memberProfile(), 'userId': 'other-user'}}
          : {'roleProfile': _roleProfile('customer')},
      ), 200)),
    ));
    provider.bindIdentity(_identity());
    await pumpEventQueue(times: 20);
    expect(provider.lastError, isA<HdcWorkflowException>());
    expect(provider.memberProfile?.bio, isEmpty);
    expect(provider.roleProfiles, isEmpty);
    await expectLater(provider.saveRoleProfile(HDCPlatformRole.technician, body: {}),
      throwsA(isA<HdcWorkflowException>().having((e) => e.code, 'code', 'invalid_server_response')));
    expect(provider.roleProfiles, isEmpty);
    provider.dispose();
  });

  test('duplicate saves are blocked and a late account switch cannot apply saved data', () async {
    final store = await _sessionStore();
    final pending = Completer<http.Response>();
    var writes = 0;
    final provider = HdcProfileProvider(client: HdcWorkflowApiClient(
      baseUri: Uri.parse('https://example.test'), sessionStore: store,
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(_overview()), 200);
        }
        writes++;
        return pending.future;
      }),
    ));
    provider.bindIdentity(_identity());
    await pumpEventQueue(times: 20);
    var sawSaving = false;
    var switched = false;
    provider.addListener(() {
      if (provider.isSaving) {
        sawSaving = true;
      }
      if (sawSaving && !provider.isSaving && !switched) {
        switched = true;
        provider.bindIdentity(null);
      }
    });
    final first = provider.saveRoleProfile(HDCPlatformRole.technician, body: {});
    final rejected = expectLater(first, throwsA(isA<HdcWorkflowException>()
      .having((e) => e.code, 'code', 'profile_request_stale')));
    await expectLater(provider.saveRoleProfile(HDCPlatformRole.technician, body: {}),
      throwsA(isA<HdcWorkflowException>().having((e) => e.code, 'code', 'profile_save_in_progress')));
    await pumpEventQueue(times: 10);
    expect(writes, 1);
    pending.complete(http.Response(jsonEncode({'roleProfile': _roleProfile('technician')}), 200));
    await rejected;
    expect(provider.memberProfile, isNull);
    expect(provider.roleProfiles, isEmpty);
    provider.dispose();
  });

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
