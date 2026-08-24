import 'account_identity.dart';

enum HDCPlatformRoleApplicationStatus {
  submitted,
  underReview,
  changesRequested,
  approved,
  rejected,
  withdrawn,
}

extension HDCPlatformRoleApplicationStatusDetails
    on HDCPlatformRoleApplicationStatus {
  String get label {
    switch (this) {
      case HDCPlatformRoleApplicationStatus.submitted:
        return 'Submitted';
      case HDCPlatformRoleApplicationStatus.underReview:
        return 'Under Review';
      case HDCPlatformRoleApplicationStatus.changesRequested:
        return 'Changes Requested';
      case HDCPlatformRoleApplicationStatus.approved:
        return 'Approved';
      case HDCPlatformRoleApplicationStatus.rejected:
        return 'Rejected';
      case HDCPlatformRoleApplicationStatus.withdrawn:
        return 'Withdrawn';
    }
  }
}

class PlatformRoleApplication {
  final String id;
  final String userId;
  final HDCPlatformRole role;
  final HDCPlatformRoleApplicationStatus status;
  final int formVersion;
  final Map<String, Object?> answers;
  final Map<String, Object?> applicantSnapshot;
  final String applicantNote;
  final String reviewNote;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? submittedAt;
  final DateTime? changesRequestedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? displayName;
  final String? email;

  const PlatformRoleApplication({
    required this.id,
    required this.userId,
    required this.role,
    required this.status,
    required this.formVersion,
    required this.answers,
    required this.applicantSnapshot,
    required this.applicantNote,
    required this.reviewNote,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.submittedAt,
    this.changesRequestedAt,
    this.displayName,
    this.email,
  });

  bool get isPending =>
      status == HDCPlatformRoleApplicationStatus.submitted ||
      status == HDCPlatformRoleApplicationStatus.underReview;

  bool get needsChanges =>
      status == HDCPlatformRoleApplicationStatus.changesRequested;

  String? get publicMemberId {
    final value = applicantSnapshot['publicMemberId'];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  factory PlatformRoleApplication.fromJson(Map<String, dynamic> json) {
    final role = parseHDCPlatformRole(json['role']);
    final status = _parseStatus(json['status']);
    if (role == null || status == null) {
      throw const FormatException('Invalid HDC platform role application.');
    }

    return PlatformRoleApplication(
      id: _requiredString(json['id']),
      userId: _requiredString(json['userId']),
      role: role,
      status: status,
      formVersion: _positiveInt(json['formVersion'], fallback: 1),
      answers: Map<String, Object?>.unmodifiable(_objectMap(json['answers'])),
      applicantSnapshot: Map<String, Object?>.unmodifiable(
        _objectMap(json['applicantSnapshot']),
      ),
      applicantNote: '${json['applicantNote'] ?? ''}',
      reviewNote: '${json['reviewNote'] ?? ''}',
      reviewedBy: _optionalString(json['reviewedBy']),
      reviewedAt: _optionalDate(json['reviewedAt']),
      submittedAt: _optionalDate(json['submittedAt']),
      changesRequestedAt: _optionalDate(json['changesRequestedAt']),
      createdAt: _requiredDate(json['createdAt']),
      updatedAt: _requiredDate(json['updatedAt']),
      displayName: _optionalString(json['displayName']),
      email: _optionalString(json['email']),
    );
  }

  static HDCPlatformRoleApplicationStatus? _parseStatus(Object? value) {
    final code = '$value'.trim().toLowerCase().replaceAll('-', '_');
    switch (code) {
      case 'pending':
      case 'submitted':
        return HDCPlatformRoleApplicationStatus.submitted;
      case 'under_review':
      case 'underreview':
        return HDCPlatformRoleApplicationStatus.underReview;
      case 'changes_requested':
      case 'changesrequested':
        return HDCPlatformRoleApplicationStatus.changesRequested;
      case 'approved':
        return HDCPlatformRoleApplicationStatus.approved;
      case 'rejected':
        return HDCPlatformRoleApplicationStatus.rejected;
      case 'withdrawn':
        return HDCPlatformRoleApplicationStatus.withdrawn;
      default:
        return null;
    }
  }
}

class RoleCenterNotification {
  final String id;
  final String eventType;
  final String priority;
  final String title;
  final String message;
  final Map<String, Object?> metadata;
  final DateTime? readAt;
  final DateTime createdAt;

  const RoleCenterNotification({
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

  factory RoleCenterNotification.fromJson(Map<String, dynamic> json) {
    return RoleCenterNotification(
      id: _requiredString(json['id']),
      eventType: _requiredString(json['eventType']),
      priority: _requiredString(json['priority']),
      title: _requiredString(json['title']),
      message: _requiredString(json['message']),
      metadata: Map<String, Object?>.unmodifiable(
        _objectMap(json['metadata']),
      ),
      readAt: _optionalDate(json['readAt']),
      createdAt: _requiredDate(json['createdAt']),
    );
  }
}

Map<String, Object?> _objectMap(Object? value) {
  final result = <String, Object?>{};
  if (value is Map) {
    for (final entry in value.entries) {
      result['${entry.key}'] = entry.value;
    }
  }
  return result;
}

int _positiveInt(Object? value, {required int fallback}) {
  if (value is int && value > 0) return value;
  if (value is num && value > 0) return value.toInt();
  return fallback;
}

String _requiredString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw const FormatException('Missing HDC role response value.');
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}

DateTime _requiredDate(Object? value) {
  final date = _optionalDate(value);
  if (date != null) return date;
  throw const FormatException('Invalid HDC role response timestamp.');
}

DateTime? _optionalDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
