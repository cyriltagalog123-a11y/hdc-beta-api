import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/messaging/private_message_moderation_service.dart';
import '../core/messaging/private_messaging_service.dart';
import '../models/private_conversation.dart';
import '../models/service_transaction.dart';
import '../repositories/private_conversation_repository.dart';
import '../repositories/private_messaging_gateway.dart';
import '../repositories/service_transaction_repository.dart';

class PrivateMessagingProvider extends ChangeNotifier {
  static const int maxMessageLength = 4000;

  final PrivateConversationRepository repository;
  final ServiceTransactionRepository transactionRepository;
  final PrivateMessagingGateway? gateway;
  final PrivateMessageModerationService moderationService;

  PrivateMessagingProvider({
    required this.repository,
    required this.transactionRepository,
    this.gateway,
    this.moderationService = const PrivateMessageModerationService(),
  });

  final Map<String, PrivateConversation> _remoteConversations = {};
  PrivateMessagingService? _service;
  String? _boundUserId;
  bool _initialized = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRefreshing = false;
  bool _disposed = false;
  Object? _lastError;
  int _bindingVersion = 0;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isRefreshing => _isRefreshing;
  Object? get lastError => _lastError;
  bool get backendAuthoritative => gateway != null;

  List<PrivateConversation> get conversations {
    if (gateway == null) return repository.getAll();
    final values = _remoteConversations.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<PrivateConversation>.unmodifiable(values);
  }

  PrivateConversation? forTransaction(String transactionId) {
    if (gateway == null) return repository.byTransactionId(transactionId);
    return _remoteConversations[transactionId];
  }

  void bindUser(String? userId) {
    if (_disposed || _boundUserId == userId) return;
    _boundUserId = userId;
    _bindingVersion += 1;
    _remoteConversations.clear();
    _lastError = null;
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _isLoading = true;
    notifyListeners();

    try {
      if (gateway == null) await repository.initialize();
      await transactionRepository.initialize();
      if (gateway == null) {
        _service = PrivateMessagingService(
          conversationRepository: repository,
          transactionRepository: transactionRepository,
          moderationService: moderationService,
        );
      }
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PrivateConversation> ensureConversation({
    required String transactionId,
    required String actorId,
  }) async {
    try {
      final remote = gateway;
      final conversation = remote == null
          ? await _requireService().ensureConversation(
              transactionId: transactionId,
              actorId: actorId,
            )
          : await _ensureRemoteConversation(
              remote,
              transactionId: transactionId,
              actorId: actorId,
            );
      _lastError = null;
      notifyListeners();
      return conversation;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    }
  }

  Future<PrivateConversation> refreshConversation({
    required String transactionId,
    required String actorId,
  }) async {
    final remote = gateway;
    if (remote == null) {
      return ensureConversation(
        transactionId: transactionId,
        actorId: actorId,
      );
    }
    _authorizedTransaction(transactionId: transactionId, actorId: actorId);
    final bindingVersion = _bindingVersion;
    if (_isRefreshing) {
      final cached = _remoteConversations[transactionId];
      if (cached != null) return cached;
    }

    _isRefreshing = true;
    notifyListeners();
    try {
      final conversation = await remote.refreshConversation(
        transactionId: transactionId,
      );
      _cache(
        conversation,
        expectedTransactionId: transactionId,
        bindingVersion: bindingVersion,
      );
      _lastError = null;
      return conversation;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isRefreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<PrivateConversation> sendMessage({
    required String transactionId,
    required String senderId,
    required String text,
    bool acknowledgeLanguageWarning = false,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty || normalizedText.length > maxMessageLength) {
      throw StateError(
        'Private messages must contain 1 to $maxMessageLength characters.',
      );
    }
    final moderation = moderationService.assess(normalizedText);
    if (moderation.isBlocked) {
      throw StateError(moderation.reason ?? 'HDC cannot send this message.');
    }
    if (moderation.requiresWarning && !acknowledgeLanguageWarning) {
      throw PrivateMessageWarningRequired(
        moderation.reason ??
            'This message contains language that may be offensive.',
      );
    }
    if (_isSaving) {
      throw StateError('Another private message is still being sent.');
    }

    _isSaving = true;
    notifyListeners();

    try {
      final remote = gateway;
      final conversation = remote == null
          ? await _requireService().sendMessage(
              transactionId: transactionId,
              senderId: senderId,
              text: normalizedText,
              acknowledgeLanguageWarning: acknowledgeLanguageWarning,
            )
          : await _sendRemoteMessage(
              remote,
              transactionId: transactionId,
              senderId: senderId,
              text: normalizedText,
              acknowledgeLanguageWarning: acknowledgeLanguageWarning,
            );
      _lastError = null;
      return conversation;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isSaving = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<PrivateConversation> markConversationRead({
    required String transactionId,
    required String readerId,
  }) async {
    final remote = gateway;
    final conversation = remote == null
        ? await _requireService().markConversationRead(
            transactionId: transactionId,
            readerId: readerId,
          )
        : await _markRemoteConversationRead(
            remote,
            transactionId: transactionId,
            readerId: readerId,
          );
    _lastError = null;
    notifyListeners();
    return conversation;
  }

  Future<PrivateConversation> updateStorageMode({
    required String transactionId,
    required String actorId,
    required ConversationStorageMode mode,
  }) async {
    final remote = gateway;
    final updated = remote == null
        ? await _requireService().updateStorageMode(
            transactionId: transactionId,
            actorId: actorId,
            mode: mode,
          )
        : await _updateRemoteStorage(
            remote,
            transactionId: transactionId,
            actorId: actorId,
            mode: mode,
          );
    _lastError = null;
    notifyListeners();
    return updated;
  }

  Future<PrivateConversation> _ensureRemoteConversation(
    PrivateMessagingGateway remote, {
    required String transactionId,
    required String actorId,
  }) async {
    _authorizedTransaction(transactionId: transactionId, actorId: actorId);
    final bindingVersion = _bindingVersion;
    final conversation = await remote.ensureConversation(
      transactionId: transactionId,
    );
    _cache(
      conversation,
      expectedTransactionId: transactionId,
      bindingVersion: bindingVersion,
    );
    return conversation;
  }

  Future<PrivateConversation> _sendRemoteMessage(
    PrivateMessagingGateway remote, {
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
    final bindingVersion = _bindingVersion;
    final conversation = await remote.sendMessage(
      transactionId: transactionId,
      text: text,
      acknowledgeLanguageWarning: acknowledgeLanguageWarning,
    );
    _cache(
      conversation,
      expectedTransactionId: transactionId,
      bindingVersion: bindingVersion,
    );
    return conversation;
  }

  Future<PrivateConversation> _markRemoteConversationRead(
    PrivateMessagingGateway remote, {
    required String transactionId,
    required String readerId,
  }) async {
    _authorizedTransaction(transactionId: transactionId, actorId: readerId);
    final bindingVersion = _bindingVersion;
    final conversation = await remote.markConversationRead(
      transactionId: transactionId,
    );
    _cache(
      conversation,
      expectedTransactionId: transactionId,
      bindingVersion: bindingVersion,
    );
    return conversation;
  }

  Future<PrivateConversation> _updateRemoteStorage(
    PrivateMessagingGateway remote, {
    required String transactionId,
    required String actorId,
    required ConversationStorageMode mode,
  }) async {
    _authorizedTransaction(transactionId: transactionId, actorId: actorId);
    final bindingVersion = _bindingVersion;
    final conversation = await remote.updateStorageMode(
      transactionId: transactionId,
      mode: mode,
    );
    _cache(
      conversation,
      expectedTransactionId: transactionId,
      bindingVersion: bindingVersion,
    );
    return conversation;
  }

  ServiceTransaction _authorizedTransaction({
    required String transactionId,
    required String actorId,
  }) {
    if (gateway != null && _boundUserId != actorId) {
      throw StateError(
        'Private chat must use the currently signed-in HDC account.',
      );
    }
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

  void _cache(
    PrivateConversation conversation, {
    required String expectedTransactionId,
    required int bindingVersion,
  }) {
    if (_bindingVersion != bindingVersion) {
      throw StateError('The HDC account changed while private chat was loading.');
    }
    final transaction = transactionRepository.byId(expectedTransactionId);
    if (conversation.transactionId != expectedTransactionId ||
        transaction == null ||
        conversation.customerId != transaction.customerId ||
        conversation.technicianId != transaction.technicianId ||
        !conversation.isParticipant(_boundUserId ?? '')) {
      throw StateError('HDC returned an invalid private conversation.');
    }
    final cached = _remoteConversations[conversation.transactionId];
    if (cached != null && _isOlderSnapshot(conversation, cached)) {
      return;
    }
    _remoteConversations[conversation.transactionId] = conversation;
  }

  bool _isOlderSnapshot(
    PrivateConversation incoming,
    PrivateConversation cached,
  ) {
    if (incoming.updatedAt.isBefore(cached.updatedAt)) return true;
    if (!incoming.updatedAt.isAtSameMomentAs(cached.updatedAt)) return false;
    return incoming.messages.length < cached.messages.length;
  }

  PrivateMessagingService _requireService() {
    final service = _service;
    if (service == null) {
      throw StateError('Private messaging is not ready yet.');
    }
    return service;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
