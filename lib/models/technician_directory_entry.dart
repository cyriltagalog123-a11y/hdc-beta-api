class TechnicianDirectoryEntry {
  final String profileId;
  final String publicMemberId;
  final String publicName;
  final String headline;
  final String description;
  final String location;
  final String contactEmail;
  final String contactPhone;
  final String website;
  final Map<String, dynamic> details;
  final DateTime updatedAt;

  const TechnicianDirectoryEntry({
    required this.profileId,
    required this.publicMemberId,
    required this.publicName,
    required this.headline,
    required this.description,
    required this.location,
    required this.contactEmail,
    required this.contactPhone,
    required this.website,
    required this.details,
    required this.updatedAt,
  });

  List<String> get skills => _stringList(details['skills']);
  List<String> get specialties => _stringList(details['specialties']);
  int? get yearsExperience => _integer(details['yearsExperience']);
  double? get serviceRadiusKm => _number(details['serviceRadiusKm']);
  double? get hourlyRate => _number(details['hourlyRate']);
  String get availability => _string(details['availability']);
  bool get emergencyService => details['emergencyService'] == true;

  String get searchableText => <String>[
    publicName,
    publicMemberId,
    headline,
    description,
    location,
    ...skills,
    ...specialties,
    availability,
  ].join(' ').toLowerCase();

  bool get hasPublicContact =>
      contactEmail.isNotEmpty || contactPhone.isNotEmpty || website.isNotEmpty;

  factory TechnicianDirectoryEntry.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    return TechnicianDirectoryEntry(
      profileId: _requiredString(json, 'profileId'),
      publicMemberId: _requiredString(json, 'publicMemberId'),
      publicName: _requiredString(json, 'publicName'),
      headline: _string(json['headline']),
      description: _string(json['description']),
      location: _string(json['location']),
      contactEmail: _string(json['contactEmail']),
      contactPhone: _string(json['contactPhone']),
      website: _string(json['website']),
      details: rawDetails is Map
          ? Map<String, dynamic>.unmodifiable(
              rawDetails.map((key, value) => MapEntry('$key', value)),
            )
          : const <String, dynamic>{},
      updatedAt:
          DateTime.tryParse(_string(json['updatedAt']))?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _string(json[key]);
  if (value.isEmpty) {
    throw FormatException('Missing technician directory field: $key');
  }
  return value;
}

String _string(Object? value) => value is String ? value.trim() : '';

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(
    value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty),
  );
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

double? _number(Object? value) => value is num ? value.toDouble() : null;
