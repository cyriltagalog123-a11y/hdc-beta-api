import '../../models/private_conversation.dart';
import '../../models/service_transaction.dart';
import '../../repositories/private_conversation_repository.dart';
import '../../repositories/service_transaction_repository.dart';
import 'private_message_moderation_service.dart';

class PrivateMessageWarningRequired implements Exception {
  final String message;

  const PrivateMessageWarningRequired(this.message);

  @override
  String toString() => message;
}

class PrivateMessagingService {
  static const int defaultBetaHdcQuotaBytes = 5 * 1024 * 1024;

  final PrivateConversationRepository conversationRepository;
  final ServiceTransactionRepository transactionRepository;
  final PrivateMessageModerationService moderationService;

  const PrivateMessagingService({
    required this.conversationRepository,
    required this.transactionRepository,
    this.moderationService = const PrivateMessageModerationService(),
  });

  Future<PrivateConversation> ensureConversation({
    required String transactionId,
    required String actorId,
  }) async {
    final transaction = _authorizedTransaction(
      transactionId: transactionId,
      actorId: actorId,
    );

    final existing =
        conversationRepository.byTransactionId(transactionId);

    if (existing != null) {
      if (!existing.isParticipant(actorId)) {
        throw StateError(
          'You are not authorized to access this private conversation.',
        );
      }
      return existing;
    }

    if (!transaction.allowsPrivateMessaging) {
      throw StateError(
        'Private messaging is not available for this transaction.',
      );
    }

    final now = DateTime.now();
    final conversation = PrivateConversation(
      id: 'CONV-${transaction.id}',
      transactionId: transaction.id,
      customerId: transaction.customerId,
      technicianId: transaction.technicianId,
      storage: ConversationStorageSettings(
        mode: ConversationStorageMode.hdcManaged,
        quotaBytes: defaultBetaHdcQuotaBytes,
        externalProviderConnected: false,
        storageChoiceConfirmed: false,
        updatedAt: now,
      ),
      messages: const [],
      createdAt: now,
      updatedAt: now,
    );

    await conversationRepository.create(conversation);
    return conversation;
  }

  Future<PrivateConversation> sendMessage({
    required String transactionId,
    required String senderId,
    required String text,
    required bool acknowledgeLanguageWarning,
  }) async {
    final transaction = _authorizedTransaction(
      transactionId: transactionId,
      actorId: senderId,
    );

    if (!transaction.allowsPrivateMessaging) {
      throw StateError(
        'Private messaging is not available for this transaction.',
      );
    }

    final conversation = await ensureConversation(
      transactionId: transactionId,
      actorId: senderId,
    );

    final moderation = moderationService.assess(text);

    if (moderation.isBlocked) {
      throw StateError(
        moderation.reason ?? 'HDC cannot send this message.',
      );
    }

    if (moderation.requiresWarning && !acknowledgeLanguageWarning) {
      throw PrivateMessageWarningRequired(
        moderation.reason ??
            'This message contains language that may be offensive.',
      );
    }

    final now = DateTime.now();
    final message = PrivateMessage(
      id: '${conversation.id}-MSG-${now.microsecondsSinceEpoch}',
      conversationId: conversation.id,
      senderId: senderId,
      body: text.trim(),
      status: PrivateMessageStatus.sent,
      languageWarningAcknowledged:
          moderation.requiresWarning && acknowledgeLanguageWarning,
      createdAt: now,
    );

    final projectedBytes =
        conversation.approximateStorageBytes + message.approximateStorageBytes;

    if (conversation.storage.mode == ConversationStorageMode.hdcManaged &&
        projectedBytes > conversation.storage.quotaBytes) {
      throw StateError(
        'HDC chat storage is full for this conversation. '
        'Free space or switch to an authorized user-owned storage provider.',
      );
    }

    if (conversation.storage.mode == ConversationStorageMode.userOwned &&
        !conversation.storage.externalProviderConnected) {
      throw StateError(
        'User-owned storage is not connected yet. '
        'Reconnect a storage provider before sending new messages.',
      );
    }

    final updated = conversation.copyWith(
      messages: [
        ...conversation.messages,
        message,
      ],
      updatedAt: now,
    );

    await conversationRepository.update(updated);
    return updated;
  }

  Future<PrivateConversation> markConversationRead({
    required String transactionId,
    required String readerId,
  }) async {
    _authorizedTransaction(
      transactionId: transactionId,
      actorId: readerId,
    );

    final conversation =
        conversationRepository.byTransactionId(transactionId);

    if (conversation == null) {
      return ensureConversation(
        transactionId: transactionId,
        actorId: readerId,
      );
    }

    final now = DateTime.now();
    var changed = false;

    final messages = conversation.messages.map((message) {
      if (message.senderId == readerId ||
          message.status == PrivateMessageStatus.read ||
          message.status == PrivateMessageStatus.deleted) {
        return message;
      }

      changed = true;
      return message.copyWith(
        status: PrivateMessageStatus.read,
        readAt: now,
      );
    }).toList(growable: false);

    if (!changed) return conversation;

    final updated = conversation.copyWith(
      messages: messages,
      updatedAt: now,
    );
    await conversationRepository.update(updated);
    return updated;
  }

  Future<PrivateConversation> updateStorageMode({
    required String transactionId,
    required String actorId,
    required ConversationStorageMode mode,
  }) async {
    _authorizedTransaction(
      transactionId: transactionId,
      actorId: actorId,
    );

    final conversation = await ensureConversation(
      transactionId: transactionId,
      actorId: actorId,
    );

    if (mode == ConversationStorageMode.userOwned &&
        !conversation.storage.externalProviderConnected) {
      throw StateError(
        'No user-owned storage provider is connected yet. '
        'The adapter is ready, but provider authorization must be added '
        'before this mode can be enabled.',
      );
    }

    final updated = conversation.copyWith(
      storage: conversation.storage.copyWith(
        mode: mode,
        storageChoiceConfirmed: true,
        updatedAt: DateTime.now(),
      ),
    );

    await conversationRepository.update(updated);
    return updated;
  }

  ServiceTransaction _authorizedTransaction({
    required String transactionId,
    required String actorId,
  }) {
    final transaction = transactionRepository.byId(transactionId);

    if (transaction == null) {
      throw StateError('Service transaction $transactionId was not found.');
    }

    if (!transaction.isParticipant(actorId)) {
      throw StateError(
        'Only transaction participants can access private chat.',
      );
    }

    return transaction;
  }
}
