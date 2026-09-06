enum HdcNewsKind { announcement, feature, maintenance, recognition }

enum HdcNewsStatus { draft, published, archived }

extension HdcNewsKindDetails on HdcNewsKind {
  String get code => name;

  String get label {
    switch (this) {
      case HdcNewsKind.announcement:
        return 'Announcement';
      case HdcNewsKind.feature:
        return 'New Feature';
      case HdcNewsKind.maintenance:
        return 'Maintenance';
      case HdcNewsKind.recognition:
        return 'Recognition';
    }
  }
}

extension HdcNewsStatusDetails on HdcNewsStatus {
  String get code => name;

  String get label {
    switch (this) {
      case HdcNewsStatus.draft:
        return 'Draft';
      case HdcNewsStatus.published:
        return 'Published';
      case HdcNewsStatus.archived:
        return 'Archived';
    }
  }
}

HdcNewsKind parseHdcNewsKind(Object? value) {
  final code = '$value'.trim().toLowerCase();
  return HdcNewsKind.values.firstWhere(
    (kind) => kind.code == code,
    orElse: () => HdcNewsKind.announcement,
  );
}

HdcNewsStatus parseHdcNewsStatus(Object? value) {
  final code = '$value'.trim().toLowerCase();
  return HdcNewsStatus.values.firstWhere(
    (status) => status.code == code,
    orElse: () => HdcNewsStatus.draft,
  );
}

DateTime? _date(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

class HdcNewsPost {
  final String id;
  final HdcNewsKind kind;
  final String title;
  final String summary;
  final String body;
  final HdcNewsStatus status;
  final bool isPinned;
  final String? recognitionSubject;
  final bool recognitionConsentConfirmed;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime updatedAt;

  const HdcNewsPost({
    required this.id,
    required this.kind,
    required this.title,
    required this.summary,
    required this.body,
    required this.status,
    required this.isPinned,
    required this.recognitionConsentConfirmed,
    required this.updatedAt,
    this.recognitionSubject,
    this.publishedAt,
    this.createdAt,
  });

  factory HdcNewsPost.fromJson(Map<String, dynamic> json) {
    return HdcNewsPost(
      id: '${json['id'] ?? ''}',
      kind: parseHdcNewsKind(json['kind']),
      title: '${json['title'] ?? ''}'.trim(),
      summary: '${json['summary'] ?? ''}'.trim(),
      body: '${json['body'] ?? ''}'.trim(),
      status: json.containsKey('status')
          ? parseHdcNewsStatus(json['status'])
          : HdcNewsStatus.published,
      isPinned: json['isPinned'] == true,
      recognitionSubject: json['recognitionSubject'] is String
          ? (json['recognitionSubject'] as String).trim()
          : null,
      recognitionConsentConfirmed:
          json['recognitionConsentConfirmed'] == true,
      publishedAt: _date(json['publishedAt']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']) ?? DateTime.now(),
    );
  }
}
