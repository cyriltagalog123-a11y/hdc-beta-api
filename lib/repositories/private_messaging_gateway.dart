import '../models/private_conversation.dart';

abstract class PrivateMessagingGateway {
  Future<PrivateConversation> ensureConversation({
    required String transactionId,
  });

  Future<PrivateConversation> refreshConversation({
    required String transactionId,
    DateTime? changedSince,
  });

  Future<PrivateConversation> sendMessage({
    required String transactionId,
    required String clientMessageId,
    required String text,
    required bool acknowledgeLanguageWarning,
  });

  Future<PrivateConversation> markConversationRead({
    required String transactionId,
  });

  Future<PrivateConversation> updateStorageMode({
    required String transactionId,
    required ConversationStorageMode mode,
  });
}
