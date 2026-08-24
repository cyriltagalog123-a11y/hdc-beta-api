import '../../models/private_conversation.dart';

class ChatStorageUsage {
  final int usedBytes;
  final int quotaBytes;

  const ChatStorageUsage({
    required this.usedBytes,
    required this.quotaBytes,
  });

  double get ratio {
    if (quotaBytes <= 0) return 0;
    return usedBytes / quotaBytes;
  }
}

/// Production implementations communicate through the authenticated HDC
/// storage API. They must not embed provider secrets or privileged external
/// storage SDKs in Flutter.
abstract interface class ChatStorageProvider {
  ConversationStorageMode get mode;

  String get displayName;

  bool get isAvailable;

  Future<void> initialize();

  Future<List<PrivateConversation>> loadAll();

  Future<void> saveAll(List<PrivateConversation> conversations);

  Future<ChatStorageUsage> usageFor(PrivateConversation conversation);
}
