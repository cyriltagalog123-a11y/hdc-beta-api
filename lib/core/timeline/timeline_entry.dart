class TimelineEntry {
  final String id;

  final String entityId;

  final String entityType;

  final String title;

  final String description;

  final DateTime timestamp;

  const TimelineEntry({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.title,
    required this.description,
    required this.timestamp,
  });
}