enum HDCPrivacyRequestType {
  access('access', 'Access my data'),
  correction('correction', 'Correct my data'),
  objection('objection', 'Object to processing'),
  export('export', 'Export my data'),
  deletion('deletion', 'Delete eligible data'),
  complaint('complaint', 'Privacy complaint'),
  other('other', 'Other privacy request');

  final String code;
  final String label;

  const HDCPrivacyRequestType(this.code, this.label);
}

class HDCPrivacyRequest {
  final String id;
  final String publicReference;
  final HDCPrivacyRequestType type;
  final String details;
  final String status;
  final String reviewerNote;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HDCPrivacyRequest({
    required this.id,
    required this.publicReference,
    required this.type,
    required this.details,
    required this.status,
    required this.reviewerNote,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HDCPrivacyRequest.fromJson(Map<String, dynamic> json) {
    final typeCode = json['requestType'];
    final type = HDCPrivacyRequestType.values
        .where((candidate) => candidate.code == typeCode)
        .firstOrNull;
    final createdAt = DateTime.tryParse('${json['createdAt'] ?? ''}');
    final updatedAt = DateTime.tryParse('${json['updatedAt'] ?? ''}');
    if (json['id'] is! String ||
        json['publicReference'] is! String ||
        type == null ||
        json['details'] is! String ||
        json['status'] is! String ||
        json['version'] is! num ||
        createdAt == null ||
        updatedAt == null) {
      throw const FormatException('Invalid HDC privacy request.');
    }
    return HDCPrivacyRequest(
      id: json['id'] as String,
      publicReference: json['publicReference'] as String,
      type: type,
      details: json['details'] as String,
      status: json['status'] as String,
      reviewerNote: json['reviewerNote'] is String
          ? json['reviewerNote'] as String
          : '',
      version: (json['version'] as num).toInt(),
      createdAt: createdAt.toLocal(),
      updatedAt: updatedAt.toLocal(),
    );
  }
}
