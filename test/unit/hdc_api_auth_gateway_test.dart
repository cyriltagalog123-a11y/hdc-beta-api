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
    'legalAcceptanceRequired': false,
    'legalVersion': hdcCurrentTermsVersion,
    'createdAt': '2026-01-02T03:04:05.000Z',
    'updatedAt': '2026-01-03T03:04:05.000Z',
  };
}

void main() {
  group('HdcApiAuthGateway', () {
    test(
      'signIn trusts backend roles and stores the opaque session token',
      () async {
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
      },
    );

    test('public signUp does not create a client session', () async {
      final store = _MemorySessionStore();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/register');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['termsAccepted'], isTrue);
        expect(body['privacyAcknowledged'], isTrue);
        expect(body['termsVersion'], hdcCurrentTermsVersion);
        expect(body['location'], 'Cebu City, Central Visayas, Philippines');
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
        location: 'Cebu City, Central Visayas, Philippines',
        recoveryAnswers: _recoveryAnswers,
        termsAccepted: true,
        privacyAcknowledged: true,
      );

      expect(identity.platformRoles, {HDCPlatformRole.customer});
      expect(identity.internalRoles, isEmpty);
      expect(identity.publicMemberId, 'HDC-M-000001');
      expect(gateway.currentSession, isNull);
      expect(store.value, isNull);
    });

    test(
      'recovery questions can authorize a one-time password reset',
      () async {
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
                  'resetToken': 'reset-token',
                }),
                200,
              );
            case '/api/auth/recovery/reset':
              final resetBody =
                  jsonDecode(request.body) as Map<String, dynamic>;
              expect(resetBody['resetToken'], 'reset-token');
              expect(resetBody['newPassword'], 'another-not-real-password');
              return http.Response(jsonEncode({'success': true}), 200);
            default:
              return http.Response(jsonEncode({'error': 'unexpected'}), 500);
          }
        });

        final gateway = HdcApiAuthGateway(
          baseUri: Uri.parse('https://example.test'),
          client: client,
          sessionStore: _MemorySessionStore(),
        );

        final challenge = await gateway.startRecovery(
          identifier: 'person@example.com',
        );
        expect(challenge.questions, hasLength(3));

        final verification = await gateway.verifyRecovery(
          identifier: 'person@example.com',
          recoveryAnswers: _recoveryAnswers,
        );
        expect(verification.resetToken, 'reset-token');

        await gateway.resetPassword(
          resetToken: verification.resetToken,
          newPassword: 'another-not-real-password',
        );
      },
    );
  });
}

const _recoveryAnswers = [
  AccountRecoveryAnswer(questionCode: 'first_meal', answer: 'ginger porridge'),
  AccountRecoveryAnswer(
    questionCode: 'childhood_nickname',
    answer: 'quiet comet',
  ),
  AccountRecoveryAnswer(questionCode: 'private_phrase', answer: 'amber harbor'),
];
