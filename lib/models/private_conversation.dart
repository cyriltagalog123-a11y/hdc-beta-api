enum ConversationStorageMode {
  hdcManaged,
  userOwned,
}

extension ConversationStorageModeDetails on ConversationStorageMode {
  String get label {
    switch (this) {
      case ConversationStorageMode.hdcManaged:
        return 'HDC Storage';
      case ConversationStorageMode.userOwned:
        return 'My Storage';
    }
  }

  String get description {
    switch (this) {
      case ConversationStorageMode.hdcManaged:
        return 'Use HDC-managed chat storage. Beta capacity is limited and '
            'may change in future versions.';
      case ConversationStorageMode.userOwned:
        return 'Use a storage provider you authorize. The provider adapter '
            'must be connected before this option can become active.';
    }
  }
}

class ConversationStorageSettings {
  final ConversationStorageMode mode;
  final int quotaBytes;
  final bool externalProviderConnected;
  final bool storageChoiceConfirmed;
  final String? externalProviderName;
  final DateTime updatedAt;

  const ConversationStorageSettings({
    required this.mode,
    required this.quotaBytes,
    required this.externalProviderConnected,
    required this.storageChoiceConfirmed,
    required this.updatedAt,
    this.externalProviderName,
  });

  Map<String, Object?> toJson() {
    return {
      'mode': mode.name,
      'quotaBytes': quotaBytes,
      'externalProviderConnected': externalProviderConnected,
      'storageChoiceConfirmed': storageChoiceConfirmed,
      'externalProviderName': externalProviderName,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ConversationStorageSettings.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConversationStorageSettings(
      mode: ConversationStorageMode.values.byName(
        json['mode'] as String,
      ),
      quotaBytes: (json['quotaBytes'] as num).toInt(),
      externalProviderConnected:
          json['externalProviderConnected'] as bool? ?? false,
      storageChoiceConfirmed:
          json['storageChoiceConfirmed'] as bool? ?? false,
      externalProviderName: json['externalProviderName'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  ConversationStorageSettings copyWith({
    ConversationStorageMode? mode,
    int? quotaBytes,
    bool? externalProviderConnected,
    bool? storageChoiceConfirmed,
    String? externalProviderName,
    bool clearExternalProviderName = false,
    DateTime? updatedAt,
  }) {
    return ConversationStorageSettings(
      mode: mode ?? this.mode,
      quotaBytes: quotaBytes ?? this.quotaBytes,
      externalProviderConnected:
          externalProviderConnected ?? this.externalProviderConnected,
      storageChoiceConfirmed:
          storageChoiceConfirmed ?? this.storageChoiceConfirmed,
      externalProviderName: clearExternalProviderName
          ? null
          : externalProviderName ?? this.externalProviderName,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

enum PrivateMessageStatus {
  sent,
  delivered,
  read,
  deleted,
}

extension PrivateMessageStatusDetails on PrivateMessageStatus {
  String get label {
    switch (this) {
      case PrivateMessageStatus.sent:
        return 'Sent';
      case PrivateMessageStatus.delivered:
        return 'Delivered';
      case PrivateMessageStatus.read:
        return 'Read';
      case PrivateMessageStatus.deleted:
        return 'Deleted';
    }
  }
}

class PrivateMessage {
  final String id;
  final String clientMessageId;
  final String conversationId;
  final String senderId;
  final String body;
  final PrivateMessageStatus status;
  final bool languageWarningAcknowledged;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;

  const PrivateMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.status,
    required this.languageWarningAcknowledged,
    required this.createdAt,
    String? clientMessageId,
    DateTime? updatedAt,
    this.readAt,
  })  : clientMessageId = clientMessageId ?? id,
        updatedAt = updatedAt ?? createdAt;

  int get approximateStorageBytes {
    return body.codeUnits.length * 2 + 160;
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'clientMessageId': clientMessageId,
      'conversationId': conversationId,
      'senderId': senderId,
      'body': body,
      'status': status.name,
      'languageWarningAcknowledged': languageWarningAcknowledged,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }

  factory PrivateMessage.fromJson(Map<String, dynamic> json) {
    final readAt = json['readAt'] as String?;
    return PrivateMessage(
      id: json['id'] as String,
      clientMessageId: json['clientMessageId'] as String?,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      body: json['body'] as String? ?? '',
      status: PrivateMessageStatus.values.byName(
        json['status'] as String,
      ),
      languageWarningAcknowledged:
          json['languageWarningAcknowledged'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      readAt: readAt == null ? null : DateTime.tryParse(readAt),
    );
  }

  PrivateMessage copyWith({
    PrivateMessageStatus? status,
    DateTime? readAt,
  }) {
    return PrivateMessage(
      id: id,
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      body: body,
      status: status ?? this.status,
      languageWarningAcknowledged: languageWarningAcknowledged,
      createdAt: createdAt,
      updatedAt: updatedAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

class PrivateConversation {
  final String id;
  final String transactionId;
  final String customerId;
  final String technicianId;
  final ConversationStorageSettings storage;
  final List<PrivateMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PrivateConversation({
    required this.id,
    required this.transactionId,
    required this.customerId,
    required this.technicianId,
    required this.storage,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isParticipant(String userId) {
    return userId == customerId || userId == technicianId;
  }

  int get approximateStorageBytes {
    return messages.fold<int>(
      0,
      (total, message) => total + message.approximateStorageBytes,
    );
  }

  double get storageUsageRatio {
    if (storage.quotaBytes <= 0) return 0;
    return approximateStorageBytes / storage.quotaBytes;
  }

  DateTime get messageSyncCursor {
    var cursor = createdAt;
    for (final message in messages) {
      if (message.updatedAt.isAfter(cursor)) cursor = message.updatedAt;
    }
    return cursor;
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'transactionId': transactionId,
      'customerId': customerId,
      'technicianId': technicianId,
      'storage': storage.toJson(),
      'messages': messages.map((message) => message.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PrivateConversation.fromJson(Map<String, dynamic> json) {
    return PrivateConversation(
      id: json['id'] as String,
      transactionId: json['transactionId'] as String,
      customerId: json['customerId'] as String,
      technicianId: json['technicianId'] as String,
      storage: ConversationStorageSettings.fromJson(
        Map<String, dynamic>.from(json['storage'] as Map),
      ),
      messages: (json['messages'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => PrivateMessage.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  PrivateConversation copyWith({
    ConversationStorageSettings? storage,
    List<PrivateMessage>? messages,
    DateTime? updatedAt,
  }) {
    return PrivateConversation(
      id: id,
      transactionId: transactionId,
      customerId: customerId,
      technicianId: technicianId,
      storage: storage ?? this.storage,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
