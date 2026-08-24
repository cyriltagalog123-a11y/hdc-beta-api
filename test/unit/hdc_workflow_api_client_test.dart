import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';

void main() {
  group('HdcWorkflowApiClient', () {
    test('sends the process session token to the HDC workflow API', () async {
      final store = MemoryAuthSessionStore();
      await store.write(
        StoredAuthSession(
          token: 'opaque-workflow-token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final httpClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/workflow/bootstrap');
        expect(
          request.headers['authorization'],
          'Bearer opaque-workflow-token',
        );
        return http.Response(
          jsonEncode({
            'serviceRequests': <Object?>[],
            'proposals': <Object?>[],
            'transactionSeeds': <Object?>[],
            'serviceTransactions': <Object?>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: httpClient,
      );

      final response = await client.get('/api/workflow/bootstrap');

      expect(response['serviceRequests'], isEmpty);
    });

    test('does not call the network without a usable session', () async {
      var networkCalled = false;
      final client = HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: MemoryAuthSessionStore(),
        client: MockClient((request) async {
          networkCalled = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.get('/api/workflow/bootstrap'),
        throwsA(
          isA<HdcWorkflowException>().having(
            (error) => error.code,
            'code',
            'authentication_required',
          ),
        ),
      );
      expect(networkCalled, isFalse);
    });

    test('maps a server conflict to an actionable workflow exception', () async {
      final store = MemoryAuthSessionStore();
      await store.write(
        StoredAuthSession(
          token: 'opaque-workflow-token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final client = HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'technician_already_selected'}),
            409,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        client.post('/api/proposals/PR-1/accept'),
        throwsA(
          isA<HdcWorkflowException>()
              .having((error) => error.statusCode, 'statusCode', 409)
              .having(
                (error) => error.message,
                'message',
                contains('already been selected'),
              ),
        ),
      );
    });
  });
}
