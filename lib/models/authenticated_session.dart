class AuthenticatedSession {
  final String id;
  final String userId;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime lastSeenAt;
  final String? deviceId;
  final bool revoked;

  const AuthenticatedSession({
    required this.id,
    required this.userId,
    required this.issuedAt,
    required this.expiresAt,
    required this.lastSeenAt,
    required this.revoked,
    this.deviceId,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isUsable => !revoked && !isExpired;

  AuthenticatedSession copyWith({
    DateTime? expiresAt,
    DateTime? lastSeenAt,
    bool? revoked,
  }) {
    return AuthenticatedSession(
      id: id,
      userId: userId,
      issuedAt: issuedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      deviceId: deviceId,
      revoked: revoked ?? this.revoked,
    );
  }
}
