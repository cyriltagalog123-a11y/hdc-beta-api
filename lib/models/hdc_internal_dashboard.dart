class HDCInternalDashboardPermissions {
  final bool canApprovePlatformRoles;
  final bool canReviewAccountRecovery;
  final bool canManageInternalStructure;
  final bool hasPrivilegedResourceAccess;
  final bool canModerateCommunity;

  const HDCInternalDashboardPermissions({
    required this.canApprovePlatformRoles,
    required this.canReviewAccountRecovery,
    required this.canManageInternalStructure,
    required this.hasPrivilegedResourceAccess,
    required this.canModerateCommunity,
  });

  factory HDCInternalDashboardPermissions.fromJson(
    Map<String, dynamic> json,
  ) {
    return HDCInternalDashboardPermissions(
      canApprovePlatformRoles: json['canApprovePlatformRoles'] == true,
      canReviewAccountRecovery: json['canReviewAccountRecovery'] == true,
      canManageInternalStructure:
          json['canManageInternalStructure'] == true,
      hasPrivilegedResourceAccess:
          json['hasPrivilegedResourceAccess'] == true,
      canModerateCommunity: json['canModerateCommunity'] == true,
    );
  }
}

class HDCInternalStaffAssignment {
  final String id;
  final String title;
  final String departmentCode;
  final String departmentName;
  final String? sectionCode;
  final String? sectionName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HDCInternalStaffAssignment({
    required this.id,
    required this.title,
    required this.departmentCode,
    required this.departmentName,
    required this.createdAt,
    required this.updatedAt,
    this.sectionCode,
    this.sectionName,
  });

  factory HDCInternalStaffAssignment.fromJson(Map<String, dynamic> json) {
    return HDCInternalStaffAssignment(
      id: _requiredString(json, 'id'),
      title: _string(json['title']),
      departmentCode: _string(json['departmentCode']),
      departmentName: _requiredString(json, 'departmentName'),
      sectionCode: _nullableString(json['sectionCode']),
      sectionName: _nullableString(json['sectionName']),
      createdAt: _requiredDate(json, 'createdAt'),
      updatedAt: _requiredDate(json, 'updatedAt'),
    );
  }
}

class HDCInternalActivity {
  final String eventType;
  final String eventStatus;
  final DateTime createdAt;

  const HDCInternalActivity({
    required this.eventType,
    required this.eventStatus,
    required this.createdAt,
  });

  factory HDCInternalActivity.fromJson(Map<String, dynamic> json) {
    return HDCInternalActivity(
      eventType: _requiredString(json, 'eventType'),
      eventStatus: _requiredString(json, 'eventStatus'),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }
}

class HDCInternalDashboardSnapshot {
  final String userId;
  final String displayName;
  final HDCInternalDashboardPermissions permissions;
  final Map<String, int> statistics;
  final List<HDCInternalStaffAssignment> assignments;
  final List<HDCInternalActivity> recentActivities;

  const HDCInternalDashboardSnapshot({
    required this.userId,
    required this.displayName,
    required this.permissions,
    required this.statistics,
    required this.assignments,
    required this.recentActivities,
  });

  factory HDCInternalDashboardSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['privateWorkspace'] != true) {
      throw const FormatException('Invalid private HDC workspace response.');
    }
    final account = _requiredObject(json, 'account');
    final permissions = _requiredObject(json, 'permissions');
    final rawStatistics = _requiredObject(json, 'statistics');
    final statistics = <String, int>{};
    for (final entry in rawStatistics.entries) {
      statistics[entry.key] = _nonNegativeInt(entry.value);
    }

    return HDCInternalDashboardSnapshot(
      userId: _requiredString(account, 'userId'),
      displayName: _requiredString(account, 'displayName'),
      permissions: HDCInternalDashboardPermissions.fromJson(permissions),
      statistics: Map<String, int>.unmodifiable(statistics),
      assignments: List<HDCInternalStaffAssignment>.unmodifiable(
        _objectList(json['assignments']).map(
          HDCInternalStaffAssignment.fromJson,
        ),
      ),
      recentActivities: List<HDCInternalActivity>.unmodifiable(
        _objectList(json['recentActivities']).map(
          HDCInternalActivity.fromJson,
        ),
      ),
    );
  }

  HDCInternalDashboardSnapshot withStatistic(String key, int value) {
    return HDCInternalDashboardSnapshot(
      userId: userId,
      displayName: displayName,
      permissions: permissions,
      statistics: Map<String, int>.unmodifiable({
        ...statistics,
        key: value < 0 ? 0 : value,
      }),
      assignments: assignments,
      recentActivities: recentActivities,
    );
  }
}

Map<String, dynamic> _requiredObject(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('Missing private HDC field: $key');
  }
  return value.map((key, value) => MapEntry('$key', value));
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) {
    throw const FormatException('Invalid private HDC list response.');
  }
  return value.map((item) {
    if (item is! Map) {
      throw const FormatException('Invalid private HDC list item.');
    }
    return item.map((key, value) => MapEntry('$key', value));
  }).toList(growable: false);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _string(json[key]).trim();
  if (value.isEmpty) throw FormatException('Missing private HDC field: $key');
  return value;
}

String _string(Object? value) => value is String ? value : '';

String? _nullableString(Object? value) {
  final result = _string(value).trim();
  return result.isEmpty ? null : result;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  final date = value is String ? DateTime.tryParse(value)?.toLocal() : null;
  if (date == null) throw FormatException('Missing private HDC field: $key');
  return date;
}

int _nonNegativeInt(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0) return value.toInt();
  throw const FormatException('Invalid private HDC statistic.');
}
