class PlatformEvent {

  final String id;

  final String type;

  final String source;

  final DateTime timestamp;

  final Map<String, dynamic> payload;

  const PlatformEvent({

    required this.id,

    required this.type,

    required this.source,

    required this.timestamp,

    required this.payload,
  });
}