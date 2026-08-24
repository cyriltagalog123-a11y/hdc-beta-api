class AuditEntry {
  final String id;

  final String entityId;

  final String entityType;

  final String action;

  final String performedBy;

  final String userRole;

  final DateTime timestamp;

  final Map<String, dynamic> metadata;

  const AuditEntry({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.action,
    required this.performedBy,
    required this.userRole,
    required this.timestamp,
    this.metadata = const {},
  });
}