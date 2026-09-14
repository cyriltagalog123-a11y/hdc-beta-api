class HdcOperationsRecord {
  final String id;
  final String title;
  final String subtitle;
  final String status;
  final Map<String, dynamic> data;
  final String createdAt;
  final String updatedAt;

  HdcOperationsRecord.fromJson(Map<String, dynamic> json)
      : id = _text(json, 'id'),
        title = _text(json, 'title'),
        subtitle = json['subtitle'] as String? ?? '',
        status = _text(json, 'status'),
        data = Map<String, dynamic>.unmodifiable(_map(json['data'])),
        createdAt = _text(json, 'created_at'),
        updatedAt = _text(json, 'updated_at');
}

class HdcOperationsSection {
  final String key;
  final String title;
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final int nextOffset;

  const HdcOperationsSection({
    required this.key,
    required this.title,
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });

  factory HdcOperationsSection.fromJson(Map<String, dynamic> json) =>
      HdcOperationsSection(
        key: _text(json, 'key'),
        title: _text(json, 'title'),
        items: List.unmodifiable(_list(json['items'])),
        hasMore: json['hasMore'] == true,
        nextOffset: json['nextOffset'] as int,
      );

  HdcOperationsSection append(HdcOperationsSection page) => HdcOperationsSection(
        key: key,
        title: title,
        items: List.unmodifiable([...items, ...page.items]),
        hasMore: page.hasMore,
        nextOffset: page.nextOffset,
      );
}

class HdcOperationsReport {
  final String userId;
  final String report;
  final String title;
  final String description;
  final String generatedAt;
  final int total;
  final int offset;
  final int limit;
  final bool hasMore;
  final List<HdcOperationsRecord> records;
  final List<HdcOperationsSection> sections;

  HdcOperationsReport.fromJson(Map<String, dynamic> json)
      : userId = _text(json, 'userId'),
        report = _text(json, 'report'),
        title = _text(json, 'title'),
        description = _text(json, 'description'),
        generatedAt = _text(json, 'generatedAt'),
        total = json['total'] as int,
        offset = json['offset'] as int,
        limit = json['limit'] as int,
        hasMore = json['hasMore'] == true,
        records = List.unmodifiable(
          _list(json['records']).map(HdcOperationsRecord.fromJson),
        ),
        sections = List.unmodifiable(
          _list(json['sections']).map(HdcOperationsSection.fromJson),
        ) {
    if (json['privateWorkspace'] != true || total < 0 || offset < 0 || limit < 1) {
      throw const FormatException('Invalid private operations report.');
    }
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) {
    throw const FormatException('Invalid operations record.');
  }
  return value.map((key, value) => MapEntry('$key', value));
}

Iterable<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) {
    throw const FormatException('Invalid operations list.');
  }
  return value.map(_map);
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing operations field: $key');
  }
  return value;
}
