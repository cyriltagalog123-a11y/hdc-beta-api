import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/models/private_conversation.dart';
import 'package:hdc_app/repositories/hdc_api_private_messaging_gateway.dart';

void main() {
  test('uses authenticated transaction-scoped private messaging routes', () async {
    final sessionStore = MemoryAuthSessionStore();
    await sessionStore.write(
      StoredAuthSession(
        token: 'opaque-messaging-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    var call = 0;
    final httpClient = MockClient((request) async {
      call += 1;
      expect(request.headers['authorization'], 'Bearer opaque-messaging-token');
      expect(
        request.url.path,
        call == 3
            ? '/api/service-transactions/TXN-1/conversation/messages'
            : call == 4
                ? '/api/service-transactions/TXN-1/conversation/read'
                : call == 5
                    ? '/api/service-transactions/TXN-1/conversation/storage'
                    : '/api/service-transactions/TXN-1/conversation',
      );

      switch (call) {
        case 1:
          expect(request.method, 'POST');
          break;
        case 2:
          expect(request.method, 'GET');
          expect(
            request.url.queryParameters['since'],
            '2026-08-27T10:00:00.000Z',
          );
          break;
        case 3:
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'clientMessageId': 'MSG-CLIENT-1',
            'text': 'Repair is complete.',
            'acknowledgeLanguageWarning': false,
          });
          break;
        case 4:
          expect(request.method, 'PUT');
          expect(jsonDecode(request.body), isEmpty);
          break;
        case 5:
          expect(request.method, 'PUT');
          expect(jsonDecode(request.body), {'mode': 'hdcManaged'});
          break;
        default:
          fail('Unexpected private messaging request.');
      }

      return http.Response(
        jsonEncode({'conversation': _conversationJson}),
        call == 1 || call == 3 ? 201 : 200,
        headers: {'content-type': 'application/json'},
      );
    });
    final gateway = HdcApiPrivateMessagingGateway(
      HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: sessionStore,
        client: httpClient,
      ),
    );

    expect(
      (await gateway.ensureConversation(transactionId: 'TXN-1')).id,
      'CONV-1',
    );
    await gateway.refreshConversation(
      transactionId: 'TXN-1',
      changedSince: DateTime.utc(2026, 8, 27, 10),
    );
    await gateway.sendMessage(
      transactionId: 'TXN-1',
      clientMessageId: 'MSG-CLIENT-1',
      text: 'Repair is complete.',
      acknowledgeLanguageWarning: false,
    );
    await gateway.markConversationRead(transactionId: 'TXN-1');
    await gateway.updateStorageMode(
      transactionId: 'TXN-1',
      mode: ConversationStorageMode.hdcManaged,
    );

    expect(call, 5);
  });
}

final Map<String, Object?> _conversationJson = {
  'id': 'CONV-1',
  'transactionId': 'TXN-1',
  'customerId': 'customer-1',
  'technicianId': 'technician-1',
  'storage': {
    'mode': 'hdcManaged',
    'quotaBytes': 5242880,
    'externalProviderConnected': false,
    'storageChoiceConfirmed': true,
    'externalProviderName': null,
    'updatedAt': '2026-08-27T10:00:00.000Z',
  },
  'messages': <Object?>[],
  'createdAt': '2026-08-27T10:00:00.000Z',
  'updatedAt': '2026-08-27T10:00:00.000Z',
};
