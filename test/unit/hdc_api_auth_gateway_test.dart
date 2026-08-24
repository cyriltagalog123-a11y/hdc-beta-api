import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hdc_app/core/auth/auth_exception.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/core/auth/hdc_api_auth_gateway.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/models/account_recovery.dart';

class _MemorySessionStore implements AuthSessionStore {
  StoredAuthSession? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<StoredAuthSession?> read() async => value;

  @override
  Future<void> write(StoredAuthSession session) async => value = session;
}

Map<String, Object?> _user({
  String id = '11111111-1111-4111-8111-111111111111',
  List<String> roles = const ['customer'],
  List<String> internalRoles = const [],
  List<String>? legacyRoles,
}) {
  return {
    'id': id,
    'publicMemberId': 'HDC-M-000001',
    'email': 'person@example.com',
    'displayName': 'HDC Person',
    'status': 'active',
    'emailVerified': false,
    'roles': legacyRoles ?? roles,
    'platformRoles': roles,
    'internalRoles': internalRoles,
    'createdAt': '2026-01-02T03:04:05.000Z',
    'updatedAt': '2026-01-03T03:04:05.000Z',
  };
}

void main() {
  group('HdcApiAuthGateway', () {
    test('signIn trusts backend roles and stores the opaque session token', () async {
      final store = _MemorySessionStore();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/login');
        expect(request.method, 'POST');
        return http.Response(
          jsonEncode({
            'token': 'opaque-token',
            'expiresAt': DateTime.now()
                .add(const Duration(hours: 2))
                .toUtc()
                .toIso8601String(),
            'user': _user(
              roles: const ['customer', 'technician'],
              internalRoles: const ['moderator'],
            ),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gateway = HdcApiAuthGateway(
        baseUri: Uri.parse('https://example.test'),
        client: client,
        sessionStore: store,
      );

      final identity = await gateway.signIn(
        identifier: 'PERSON@EXAMPLE.COM',
        password: 'not-a-real-password',
      );

      expect(identity.hasPlatformRole(HDCPlatformRole.customer), isTrue);
      expect(identity.hasPlatformRole(HDCPlatformRole.technician), isTrue);
      expect(identity.hasInternalRole(HDCInternalRole.moderator), isTrue);
      expect(identity.hasPrivilegedRole, isFalse);
      expect(gateway.currentSession?.isUsable, isTrue);
      expect(store.value?.token, 'opaque-token');
    });

    test('public signUp does not create a client session', () async {
      final store = _MemorySessionStore();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/register');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['termsAccepted'], isTrue);
        expect(body['termsVersion'], hdcCurrentTermsVersion);
        expect(body['recoveryAnswers'], hasLength(3));
        return http.Response(
          jsonEncode({'user': _user()}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final gateway = HdcApiAuthGateway(
        baseUri: Uri.parse('https://example.test'),
        client: client,
        sessionStore: store,
      );

      final identity = await gateway.signUp(
        email: 'person@example.com',
        password: 'not-a-real-password',
        displayName: 'HDC Person',
        recoveryAnswers: _recoveryAnswers,
        termsAccepted: true,
      );

      expect(identity.platformRoles, {HDCPlatformRole.customer});
      expect(identity.internalRoles, isEmpty);
      expect(identity.publicMemberId, 'HDC-M-000001');
      expect(gateway.currentSession, isNull);
      expect(store.value, isNull);
    });

    test('recovery questions can authorize a one-time password reset', () async {
      final client = MockClient((request) async {
        switch (request.url.path) {
          case '/api/auth/recovery/start':
            return http.Response(
              jsonEncode({
                'questionVersion': 1,
                'questions': [
                  for (final question in hdcRegistrationRecoveryQuestions)
                    {
                      'questionCode': question.questionCode,
                      'prompt': question.prompt,
                    },
                ],
              }),
              200,
            );
          case '/api/auth/recovery/verify':
            final verifyBody =
                jsonDecode(request.body) as Map<String, dynamic>;
            expect(verifyBody['answers'], hasLength(3));
            return http.Response(
              jsonEncode({
                'result': 'verified',
                'resetToken': 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                'expiresAt': DateTime.now()
                    .add(const Duration(minutes: 15))
                    .toUtc()
                    .toIso8601String(),
              }),
              200,
            );
          case '/api/auth/recovery/reset':
            final resetBody =
                jsonDecode(request.body) as Map<String, dynamic>;
            expect(
              resetBody['resetToken'],
              'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
            );
            expect(resetBody['newPassword'], 'New-Secure-Password#12');
            return http.Response(jsonEncode({'success': true}), 200);
          default:
            return http.Response('{}', 404);
        }
      });
      final gateway = HdcApiAuthGateway(
        baseUri: Uri.parse('https://example.test'),
        client: client,
        sessionStore: _MemorySessionStore(),
      );

      final questions = await gateway.startPasswordRecovery(
        email: 'person@example.com',
      );
      expect(questions, hasLength(3));
      final verification = await gateway.verifyRecoveryAnswers(
        email: 'person@example.com',
        answers: _recoveryAnswers,
      );
      expect(verification.isVerified, isTrue);
      await gateway.resetPassword(
        resetToken: verification.resetToken!,
        newPassword: 'New-Secure-Password#12',
      );
    });

    test('authenticated accounts can replace recovery answers', () async {
      final store = _MemorySessionStore()
        ..value = StoredAuthSession(
          token: 'security-token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/recovery/answers');
        expect(request.headers['authorization'], 'Bearer security-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['currentPassword'], 'Current-Secure-Password#12');
        expect(body['recoveryAnswers'], hasLength(3));
        return http.Response(jsonEncode({'success': true}), 200);
      });
      final gateway = HdcApiAuthGateway(
        baseUri: Uri.parse('https://example.test'),
        client: client,
        sessionStore: store,
      );

      await gateway.updateRecoveryAnswers(
        currentPassword: 'Current-Secure-Password#12',
        recoveryAnswers: _recoveryAnswers,
      );
    });

    test('rejects a malformed or shared account identifier', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'user': _user(id: 'shared-account')}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final gateway = HdcApiAuthGateway(
        baseUri: Uri.parse('https://example.test'),
        client: client,
        sessionStore: _MemorySessionStore(),
      );

      await expectLater(
        gateway.signUp(
          email: 'person@example.com',
          password: 'not-a-real-password',
          displayName: 'HDC Person',
          recoveryAnswers: _recoveryAnswers,
          termsAccepted: true,
        ),
        throwsA(
          isA<HDCAuthException>().having(
            (error) => error.code,
            'code',
            'invalid_server_response',
          ),
        ),
      );
    });

    test('initialize restores only a session verified by the backend', () async {
      final store = _MemorySessionStore()
        ..value = StoredAuthSession(
          token: 'restored-token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/session');
        expect(request.headers['authorization'], 'Bearer restored-token');
        return http.Response(
          jsonEncode({'user': _user()}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gateway = HdcApiAuthGateway(
        baseUri: Uri.parse('https://example.test'),
        client: client,
        sessionStore: store,
      );

      await gateway.initialize();

      expect(gateway.currentIdentity?.email, 'person@example.com');
      expect(gateway.currentSession?.isUsable, isTrue);
    });

    test('legacy mixed role payload is split into separate domains', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'token': 'legacy-token',
            'expiresAt': DateTime.now()
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'user': {
              ..._user(),
              'platformRoles': null,
              'internalRoles': null,
              'roles': ['customer', 'supplier', 'super_admin', 'unknown'],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gateway = HdcApiAuthGateway(
        baseUri: Uri.parse('https://example.test'),
        client: client,
        sessionStore: _MemorySessionStore(),
      );
      final identity = await gateway.signIn(
        identifier: 'person@example.com',
        password: 'not-a-real-password',
      );

      expect(identity.platformRoles, {
        HDCPlatformRole.customer,
        HDCPlatformRole.supplier,
      });
      expect(identity.internalRoles, {HDCInternalRole.superAdmin});
      expect(identity.canApprovePlatformRoles, isTrue);
    });

    test('default session policy does not restore login after app restart', () async {
      final loginClient = MockClient((request) async {
        expect(request.url.path, '/api/auth/login');
        return http.Response(
          jsonEncode({
            'token': 'process-only-token',
            'expiresAt': DateTime.now()
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'user': _user(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final firstRun = HdcApiAuthGateway(
        baseUri: Uri.parse('https://example.test'),
        client: loginClient,
      );
      await firstRun.signIn(
        identifier: 'person@example.com',
        password: 'not-a-real-password',
      );
      expect(firstRun.currentSession?.isUsable, isTrue);

      var networkCalled = false;
      final secondRun = HdcApiAuthGateway(
        baseUri: Uri.parse('https://example.test'),
        client: MockClient((request) async {
          networkCalled = true;
          return http.Response('{}', 500);
        }),
      );

      await secondRun.initialize();

      expect(networkCalled, isFalse);
      expect(secondRun.currentIdentity, isNull);
      expect(secondRun.currentSession, isNull);
    });

    test('signOut revokes the backend session before clearing local state', () async {
      final store = _MemorySessionStore();
      var logoutCalled = false;
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({
              'token': 'logout-token',
              'expiresAt': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toUtc()
                  .toIso8601String(),
              'user': _user(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/auth/logout') {
          logoutCalled = true;
          expect(request.headers['authorization'], 'Bearer logout-token');
          return http.Response(
            jsonEncode({'success': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final gateway = HdcApiAuthGateway(
        baseUri: Uri.parse('https://example.test'),
        client: client,
        sessionStore: store,
      );
      await gateway.signIn(
        identifier: 'person@example.com',
        password: 'not-a-real-password',
      );

      await gateway.signOut();

      expect(logoutCalled, isTrue);
      expect(gateway.currentIdentity, isNull);
      expect(gateway.currentSession, isNull);
      expect(store.value, isNull);
    });


    test('signOut clears the local token when remote revocation is unreachable', () async {
      final store = _MemorySessionStore();
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({
              'token': 'offline-logout-token',
              'expiresAt': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toUtc()
                  .toIso8601String(),
              'user': _user(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/auth/logout') {
          throw http.ClientException('offline');
        }
        return http.Response('{}', 404);
      });

      final gateway = HdcApiAuthGateway(
        baseUri: Uri.parse('https://example.test'),
        client: client,
        sessionStore: store,
      );
      await gateway.signIn(
        identifier: 'person@example.com',
        password: 'not-a-real-password',
      );

      await gateway.signOut();

      expect(gateway.currentIdentity, isNull);
      expect(gateway.currentSession, isNull);
      expect(store.value, isNull);
    });
  });
}

const _recoveryAnswers = <AccountRecoveryAnswer>[
  AccountRecoveryAnswer(
    questionCode: 'first_meal',
    answer: 'private meal answer',
  ),
  AccountRecoveryAnswer(
    questionCode: 'childhood_nickname',
    answer: 'private nickname answer',
  ),
  AccountRecoveryAnswer(
    questionCode: 'private_phrase',
    answer: 'private phrase answer',
  ),
];
