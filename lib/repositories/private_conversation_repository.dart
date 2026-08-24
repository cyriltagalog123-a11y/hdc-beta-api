import '../models/private_conversation.dart';

abstract class PrivateConversationRepository {
  Future<void> initialize();

  List<PrivateConversation> getAll();

  PrivateConversation? byId(String id);

  PrivateConversation? byTransactionId(String transactionId);

  Future<void> create(PrivateConversation conversation);

  Future<void> update(PrivateConversation conversation);

  Future<void> delete(String id);
}
