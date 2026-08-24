import 'package:flutter/foundation.dart';

import '../core/messaging/private_messaging_service.dart';
import '../models/private_conversation.dart';
import '../repositories/private_conversation_repository.dart';
import '../repositories/service_transaction_repository.dart';

class PrivateMessagingProvider extends ChangeNotifier {
  final PrivateConversationRepository repository;
  final ServiceTransactionRepository transactionRepository;

  PrivateMessagingProvider({
    required this.repository,
    required this.transactionRepository,
  });

  PrivateMessagingService? _service;
  bool _initialized = false;
  bool _isLoading = true;
  bool _isSaving = false;
  Object? _lastError;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get lastError => _lastError;

  List<PrivateConversation> get conversations => repository.getAll();

  PrivateConversation? forTransaction(String transactionId) {
    return repository.byTransactionId(transactionId);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _isLoading = true;
    notifyListeners();

    try {
      await repository.initialize();
      await transactionRepository.initialize();
      _service = PrivateMessagingService(
        conversationRepository: repository,
        transactionRepository: transactionRepository,
      );
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
    final service = _requireService();

    try {
      final conversation = await service.ensureConversation(
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

  Future<PrivateConversation> sendMessage({
    required String transactionId,
    required String senderId,
    required String text,
    bool acknowledgeLanguageWarning = false,
  }) async {
    final service = _requireService();

    _isSaving = true;
    notifyListeners();

    try {
      final conversation = await service.sendMessage(
        transactionId: transactionId,
        senderId: senderId,
        text: text,
        acknowledgeLanguageWarning: acknowledgeLanguageWarning,
      );
      _lastError = null;
      return conversation;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<PrivateConversation> markConversationRead({
    required String transactionId,
    required String readerId,
  }) async {
    final service = _requireService();
    final conversation = await service.markConversationRead(
      transactionId: transactionId,
      readerId: readerId,
    );
    notifyListeners();
    return conversation;
  }

  Future<PrivateConversation> updateStorageMode({
    required String transactionId,
    required String actorId,
    required ConversationStorageMode mode,
  }) async {
    final service = _requireService();
    final updated = await service.updateStorageMode(
      transactionId: transactionId,
      actorId: actorId,
      mode: mode,
    );
    notifyListeners();
    return updated;
  }

  PrivateMessagingService _requireService() {
    final service = _service;
    if (service == null) {
      throw StateError('Private messaging is not ready yet.');
    }
    return service;
  }
}
