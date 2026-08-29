import '../core/api/hdc_workflow_api_client.dart';
import '../models/private_conversation.dart';
import 'private_messaging_gateway.dart';

class HdcApiPrivateMessagingGateway implements PrivateMessagingGateway {
  final HdcWorkflowApiClient client;

  const HdcApiPrivateMessagingGateway(this.client);

  @override
  Future<PrivateConversation> ensureConversation({
    required String transactionId,
  }) async {
    final response = await client.post(_conversationPath(transactionId));
    return _conversation(response);
  }

  @override
  Future<PrivateConversation> refreshConversation({
    required String transactionId,
    DateTime? changedSince,
  }) async {
    final basePath = _conversationPath(transactionId);
    final path = changedSince == null
        ? basePath
        : '$basePath?since=${Uri.encodeQueryComponent(changedSince.toUtc().toIso8601String())}';
    final response = await client.get(path);
    return _conversation(response);
  }

  @override
  Future<PrivateConversation> sendMessage({
    required String transactionId,
    required String clientMessageId,
    required String text,
    required bool acknowledgeLanguageWarning,
  }) async {
    final response = await client.post(
      '${_conversationPath(transactionId)}/messages',
      body: {
        'clientMessageId': clientMessageId,
        'text': text,
        'acknowledgeLanguageWarning': acknowledgeLanguageWarning,
      },
    );
    return _conversation(response);
  }

  @override
  Future<PrivateConversation> markConversationRead({
    required String transactionId,
  }) async {
    final response = await client.put(
      '${_conversationPath(transactionId)}/read',
      body: const <String, Object?>{},
    );
    return _conversation(response);
  }

  @override
  Future<PrivateConversation> updateStorageMode({
    required String transactionId,
    required ConversationStorageMode mode,
  }) async {
    final response = await client.put(
      '${_conversationPath(transactionId)}/storage',
      body: {'mode': mode.name},
    );
    return _conversation(response);
  }

  String _conversationPath(String transactionId) =>
      '/api/service-transactions/'
      '${Uri.encodeComponent(transactionId)}/conversation';

  PrivateConversation _conversation(Map<String, dynamic> response) {
    final value = response['conversation'];
    if (value is! Map) {
      throw const HdcWorkflowException(
        code: 'invalid_server_response',
        message: 'HDC returned incomplete private messaging data.',
      );
    }
    return PrivateConversation.fromJson(
      value.map((key, value) => MapEntry('$key', value)),
    );
  }
}
