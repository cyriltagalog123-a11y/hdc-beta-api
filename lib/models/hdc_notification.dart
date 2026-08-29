class HdcNotification {
  final String id;
  final String eventType;
  final String priority;
  final String title;
  final String message;
  final Map<String, Object?> metadata;
  final DateTime? readAt;
  final DateTime createdAt;

  const HdcNotification({
    required this.id,
    required this.eventType,
    required this.priority,
    required this.title,
    required this.message,
    required this.metadata,
    required this.createdAt,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  factory HdcNotification.fromJson(Map<String, dynamic> json) {
    final metadataValue = json['metadata'];
    final readAtValue = json['readAt'];
    return HdcNotification(
      id: '${json['id'] ?? ''}',
      eventType: '${json['eventType'] ?? ''}',
      priority: '${json['priority'] ?? 'normal'}',
      title: '${json['title'] ?? ''}',
      message: '${json['message'] ?? ''}',
      metadata: metadataValue is Map
          ? Map<String, Object?>.unmodifiable(
              metadataValue.map((key, value) => MapEntry('$key', value)),
            )
          : const {},
      readAt: readAtValue is String ? DateTime.tryParse(readAtValue) : null,
      createdAt: DateTime.tryParse('${json['createdAt']}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  HdcNotification copyWith({DateTime? readAt}) {
    return HdcNotification(
      id: id,
      eventType: eventType,
      priority: priority,
      title: title,
      message: message,
      metadata: metadata,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}
