class AccountRecoveryReviewRequest {
  final String id;
  final String userId;
  final String publicMemberId;
  final String displayName;
  final String email;
  final String status;
  final String deliveryStatus;
  final String reviewerNote;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountRecoveryReviewRequest({
    required this.id,
    required this.userId,
    required this.publicMemberId,
    required this.displayName,
    required this.email,
    required this.status,
    required this.deliveryStatus,
    required this.reviewerNote,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory AccountRecoveryReviewRequest.fromJson(Map<String, dynamic> json) {
    return AccountRecoveryReviewRequest(
      id: _requiredString(json['id']),
      userId: _requiredString(json['userId']),
      publicMemberId: _requiredString(json['publicMemberId']),
      displayName: _requiredString(json['displayName']),
      email: _requiredString(json['email']),
      status: _requiredString(json['status']),
      deliveryStatus: _requiredString(json['deliveryStatus']),
      reviewerNote: '${json['reviewerNote'] ?? ''}',
      reviewedBy: _optionalString(json['reviewedBy']),
      reviewedAt: _optionalDate(json['reviewedAt']),
      createdAt: _requiredDate(json['createdAt']),
      updatedAt: _requiredDate(json['updatedAt']),
    );
  }
}

class AccountRecoveryReviewResult {
  final AccountRecoveryReviewRequest request;
  final String? manualResetToken;
  final DateTime? expiresAt;

  const AccountRecoveryReviewResult({
    required this.request,
    this.manualResetToken,
    this.expiresAt,
  });

  factory AccountRecoveryReviewResult.fromJson(Map<String, dynamic> json) {
    final rawRequest = json['request'];
    if (rawRequest is! Map) {
      throw const FormatException('Invalid HDC recovery review response.');
    }
    return AccountRecoveryReviewResult(
      request: AccountRecoveryReviewRequest.fromJson(
        rawRequest.map((key, value) => MapEntry('$key', value)),
      ),
      manualResetToken: _optionalString(json['resetToken']),
      expiresAt: _optionalDate(json['expiresAt']),
    );
  }
}

String _requiredString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw const FormatException('Missing HDC recovery review value.');
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}

DateTime _requiredDate(Object? value) {
  final date = _optionalDate(value);
  if (date != null) return date;
  throw const FormatException('Invalid HDC recovery review timestamp.');
}

DateTime? _optionalDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
