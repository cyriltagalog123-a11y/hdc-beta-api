import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/private_conversation.dart';
import 'private_conversation_repository.dart';

class SharedPreferencesPrivateConversationRepository
    implements PrivateConversationRepository {
  static const _storageKey = 'hdc_private_conversations_v1';

  final List<PrivateConversation> _conversations = [];
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);

    if (stored != null && stored.trim().isNotEmpty) {
      final decoded = jsonDecode(stored);

      if (decoded is List) {
        _conversations
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map(
                  (item) => PrivateConversation.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                ),
          );
      }
    }

    _initialized = true;
  }

  @override
  List<PrivateConversation> getAll() {
    final result = [..._conversations]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<PrivateConversation>.unmodifiable(result);
  }

  @override
  PrivateConversation? byId(String id) {
    for (final conversation in _conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  @override
  PrivateConversation? byTransactionId(String transactionId) {
    for (final conversation in _conversations) {
      if (conversation.transactionId == transactionId) {
        return conversation;
      }
    }
    return null;
  }

  @override
  Future<void> create(PrivateConversation conversation) async {
    if (byId(conversation.id) != null ||
        byTransactionId(conversation.transactionId) != null) {
      throw StateError(
        'A private conversation already exists for this transaction.',
      );
    }

    _conversations.add(conversation);
    await _persist();
  }

  @override
  Future<void> update(PrivateConversation conversation) async {
    final index = _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );

    if (index == -1) {
      throw StateError(
        'Private conversation ${conversation.id} was not found.',
      );
    }

    _conversations[index] = conversation;
    await _persist();
  }

  @override
  Future<void> delete(String id) async {
    _conversations.removeWhere((item) => item.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _storageKey,
      jsonEncode(
        _conversations.map((item) => item.toJson()).toList(),
      ),
    );

    if (!saved) {
      throw StateError('Private chat history could not be saved.');
    }
  }
}
