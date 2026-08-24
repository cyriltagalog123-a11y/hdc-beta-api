import 'account_identity.dart';

class HDCMemberProfile {
  final String userId;
  final String displayName;
  final String email;
  final String bio;
  final String location;
  final String avatarUrl;
  final String contactPreference;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HDCMemberProfile({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.bio,
    required this.location,
    required this.avatarUrl,
    required this.contactPreference,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  int get completionPercent {
    final completed = <bool>[
      displayName.trim().isNotEmpty,
      email.trim().isNotEmpty,
      bio.trim().isNotEmpty,
      location.trim().isNotEmpty,
      avatarUrl.trim().isNotEmpty,
    ].where((value) => value).length;
    return (completed * 100 / 5).round();
  }

  factory HDCMemberProfile.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return HDCMemberProfile(
      userId: _requiredString(json, 'userId'),
      displayName: _requiredString(json, 'displayName'),
      email: _string(json['email']),
      bio: _string(json['bio']),
      location: _string(json['location']),
      avatarUrl: _string(json['avatarUrl']),
      contactPreference: _string(json['contactPreference']).isEmpty
          ? 'in_app'
          : _string(json['contactPreference']),
      version: _positiveInt(json['version']),
      createdAt: _date(json['createdAt']) ?? now,
      updatedAt: _date(json['updatedAt']) ?? now,
    );
  }
}

class HDCPlatformRoleProfile {
  final String id;
  final String userId;
  final HDCPlatformRole role;
  final String publicName;
  final String headline;
  final String description;
  final String location;
  final String contactEmail;
  final String contactPhone;
  final String website;
  final bool isPublic;
  final Map<String, dynamic> details;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HDCPlatformRoleProfile({
    required this.id,
    required this.userId,
    required this.role,
    required this.publicName,
    required this.headline,
    required this.description,
    required this.location,
    required this.contactEmail,
    required this.contactPhone,
    required this.website,
    required this.isPublic,
    required this.details,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  int get completionPercent {
    final hasPublicContact = contactEmail.trim().isNotEmpty ||
        contactPhone.trim().isNotEmpty ||
        website.trim().isNotEmpty;
    final hasRoleDetails = details.values.any(_hasProfileValue);
    final completed = <bool>[
      publicName.trim().isNotEmpty,
      headline.trim().isNotEmpty,
      description.trim().isNotEmpty,
      location.trim().isNotEmpty,
      hasPublicContact,
      hasRoleDetails,
    ].where((value) => value).length;
    return (completed * 100 / 6).round();
  }

  factory HDCPlatformRoleProfile.fromJson(Map<String, dynamic> json) {
    final role = parseHDCPlatformRole(json['role']);
    if (role == null) {
      throw const FormatException('Invalid HDC platform role profile.');
    }
    final now = DateTime.now();
    final rawDetails = json['details'];
    return HDCPlatformRoleProfile(
      id: _requiredString(json, 'id'),
      userId: _requiredString(json, 'userId'),
      role: role,
      publicName: _requiredString(json, 'publicName'),
      headline: _string(json['headline']),
      description: _string(json['description']),
      location: _string(json['location']),
      contactEmail: _string(json['contactEmail']),
      contactPhone: _string(json['contactPhone']),
      website: _string(json['website']),
      isPublic: json['isPublic'] == true,
      details: rawDetails is Map
          ? Map<String, dynamic>.unmodifiable(
              rawDetails.map((key, value) => MapEntry('$key', value)),
            )
          : const <String, dynamic>{},
      version: _positiveInt(json['version']),
      createdAt: _date(json['createdAt']) ?? now,
      updatedAt: _date(json['updatedAt']) ?? now,
    );
  }
}

class HDCProfileBundle {
  final HDCMemberProfile memberProfile;
  final Map<HDCPlatformRole, HDCPlatformRoleProfile> roleProfiles;

  const HDCProfileBundle({
    required this.memberProfile,
    required this.roleProfiles,
  });

  factory HDCProfileBundle.fromJson(Map<String, dynamic> json) {
    final member = _object(json['memberProfile']);
    if (member == null) {
      throw const FormatException('HDC member profile is missing.');
    }
    final profiles = <HDCPlatformRole, HDCPlatformRoleProfile>{};
    for (final value in _objectList(json['roleProfiles'])) {
      final profile = HDCPlatformRoleProfile.fromJson(value);
      profiles[profile.role] = profile;
    }
    return HDCProfileBundle(
      memberProfile: HDCMemberProfile.fromJson(member),
      roleProfiles: Map<HDCPlatformRole, HDCPlatformRoleProfile>.unmodifiable(
        profiles,
      ),
    );
  }
}

bool _hasProfileValue(Object? value) {
  if (value is String) return value.trim().isNotEmpty;
  if (value is num) return true;
  if (value is bool) return value;
  if (value is List) return value.isNotEmpty;
  return false;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _string(json[key]);
  if (value.isEmpty) throw FormatException('Missing HDC profile field: $key');
  return value;
}

String _string(Object? value) => value is String ? value : '';

int _positiveInt(Object? value) {
  if (value is int && value > 0) return value;
  if (value is num && value > 0) return value.toInt();
  return 1;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

Map<String, dynamic>? _object(Object? value) {
  if (value is! Map) return null;
  return value.map((key, value) => MapEntry('$key', value));
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry('$key', value)))
      .toList(growable: false);
}
