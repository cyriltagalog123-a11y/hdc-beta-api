import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/account_identity.dart';
import '../../models/account_recovery.dart';
import '../../models/authenticated_session.dart';
import 'auth_exception.dart';
import 'auth_gateway.dart';
import 'auth_session_store.dart';

class HdcApiAuthGateway implements AuthGateway {
  static const _requestTimeout = Duration(seconds: 20);

  final Uri baseUri;
  final http.Client _client;
  final AuthSessionStore _sessionStore;

  AccountIdentity? _currentIdentity;
  AuthenticatedSession? _currentSession;
  StoredAuthSession? _storedSession;

  HdcApiAuthGateway({
    required this.baseUri,
    http.Client? client,
    AuthSessionStore? sessionStore,
  })  : _client = client ?? http.Client(),
        _sessionStore = sessionStore ?? MemoryAuthSessionStore();

  @override
  AccountIdentity? get currentIdentity => _currentIdentity;

  @override
  AuthenticatedSession? get currentSession => _currentSession;

  @override
  Future<void> initialize() async {
    // HDC beta policy: sessions are process-local unless a future explicit
    // "Remember me" option is enabled. Closing the app therefore returns the
    // user to the sign-in / Guest screen on the next launch.
    //
    // Build 4 also cleans up a token left by the earlier always-persistent
    // policy. Revocation/cleanup is best-effort so a platform storage issue
    // can never block HDC from reaching the sign-in screen.
    if (_sessionStore is MemoryAuthSessionStore) {
      await _clearLegacyPersistentSession();
    }

    final stored = await _sessionStore.read();
    if (stored == null) {
      _clearMemory();
      return;
    }

    if (stored.isExpired) {
      await _clearLocalSession();
      return;
    }

    _storedSession = stored;

    try {
      final response = await _get(
        '/api/auth/session',
        token: stored.token,
      );

      if (response.statusCode == 401) {
        await _clearLocalSession();
        return;
      }

      final body = _requireSuccessObject(response);
      final user = _requireObject(body, 'user');
      _hydrate(
        user: user,
        expiresAt: stored.expiresAt,
      );
    } on HDCAuthException {
      rethrow;
    } on Object {
      // Keep any selected session-store state intact for this app run. The app
      // stays unauthenticated until the HDC backend verifies the session.
      _clearMemory(keepStoredSession: true);
      rethrow;
    }
  }

  @override
  Future<AccountIdentity> signIn({
    required String identifier,
    required String password,
  }) async {
    final response = await _post(
      '/api/auth/login',
      body: {
        'email': identifier.trim().toLowerCase(),
        'password': password,
      },
    );
    final body = _requireSuccessObject(response);

    final token = body['token'];
    final expiresAtValue = body['expiresAt'];
    final user = _requireObject(body, 'user');

    if (token is! String || token.isEmpty || expiresAtValue is! String) {
      throw const HDCAuthException(
        code: 'invalid_server_response',
        message: 'HDC authentication returned an invalid session response.',
      );
    }

    final expiresAt = DateTime.tryParse(expiresAtValue)?.toLocal();
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now())) {
      throw const HDCAuthException(
        code: 'invalid_server_response',
        message: 'HDC authentication returned an invalid session expiry.',
      );
    }

    final stored = StoredAuthSession(
      token: token,
      expiresAt: expiresAt,
    );
    try {
      await _sessionStore.write(stored);
    } on Object {
      // Do not leave a server-side session active if this device cannot safely
      // retain the token for the selected session policy.
      try {
        await _post('/api/auth/logout', token: token);
      } on Object {
        // The storage failure remains the primary error presented to the user.
      }
      _clearMemory();
      rethrow;
    }
    _storedSession = stored;
    _hydrate(user: user, expiresAt: expiresAt);
    return _currentIdentity!;
  }

  @override
  Future<AccountIdentity> signUp({
    required String email,
    required String password,
    required String displayName,
    required List<AccountRecoveryAnswer> recoveryAnswers,
    required bool termsAccepted,
  }) async {
    final response = await _post(
      '/api/auth/register',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'displayName': displayName.trim(),
        'recoveryAnswers': recoveryAnswers
            .map((answer) => answer.toJson())
            .toList(growable: false),
        'termsAccepted': termsAccepted,
        'termsVersion': hdcCurrentTermsVersion,
      },
    );
    final body = _requireSuccessObject(response);
    final user = _requireObject(body, 'user');

    // Registration deliberately does not create a session. Public account
    // creation always starts as a backend-owned Customer role, then the user
    // signs in through the normal login flow.
    return _identityFromJson(user);
  }

  @override
  Future<void> signOut() async {
    final stored = _storedSession ?? await _sessionStore.read();
    if (stored == null) {
      await _clearLocalSession();
      return;
    }

    try {
      // Remote revocation is best-effort on explicit logout. Whether the
      // backend confirms, rejects, or cannot receive this request, the device
      // credential is removed in the finally block below.
      await _post(
        '/api/auth/logout',
        token: stored.token,
      );
    } on Object {
      // Offline logout still clears the device credential below. The backend
      // session remains bounded by its server-side expiry if it could not be
      // revoked during this request.
    } finally {
      await _clearLocalSession();
    }
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await startPasswordRecovery(email: email);
  }

  @override
  Future<List<AccountRecoveryQuestion>> startPasswordRecovery({
    required String email,
  }) async {
    final response = await _post(
      '/api/auth/recovery/start',
      body: {'email': email.trim().toLowerCase()},
    );
    final body = _requireSuccessObject(response);
    final rawQuestions = body['questions'];
    if (rawQuestions is! List || rawQuestions.length != 3) {
      throw const HDCAuthException(
        code: 'invalid_server_response',
        message: 'HDC returned invalid recovery questions.',
      );
    }
    try {
      return List<AccountRecoveryQuestion>.unmodifiable(
        rawQuestions.map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid HDC recovery question.');
          }
          return AccountRecoveryQuestion.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          );
        }),
      );
    } on FormatException {
      throw const HDCAuthException(
        code: 'invalid_server_response',
        message: 'HDC returned invalid recovery questions.',
      );
    }
  }

  @override
  Future<AccountRecoveryVerification> verifyRecoveryAnswers({
    required String email,
    required List<AccountRecoveryAnswer> answers,
  }) async {
    final response = await _post(
      '/api/auth/recovery/verify',
      body: {
        'email': email.trim().toLowerCase(),
        'answers': answers
            .map((answer) => answer.toJson())
            .toList(growable: false),
      },
    );
    final body = _requireSuccessObject(response);
    try {
      return AccountRecoveryVerification.fromJson(body);
    } on FormatException {
      throw const HDCAuthException(
        code: 'invalid_server_response',
        message: 'HDC returned an invalid recovery result.',
      );
    }
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    final response = await _post(
      '/api/auth/recovery/reset',
      body: {
        'resetToken': resetToken.trim(),
        'newPassword': newPassword,
      },
    );
    _requireSuccessObject(response);
  }

  @override
  Future<void> updateRecoveryAnswers({
    required String currentPassword,
    required List<AccountRecoveryAnswer> recoveryAnswers,
  }) async {
    final stored = _storedSession ?? await _sessionStore.read();
    if (stored == null || stored.isExpired) {
      throw const HDCAuthException(
        code: 'session_expired',
        message: 'Your HDC session has expired. Please sign in again.',
        statusCode: 401,
      );
    }
    final response = await _post(
      '/api/auth/recovery/answers',
      token: stored.token,
      body: {
        'currentPassword': currentPassword,
        'recoveryAnswers': recoveryAnswers
            .map((answer) => answer.toJson())
            .toList(growable: false),
      },
    );
    _requireSuccessObject(response);
  }

  @override
  Future<void> refreshSession() async {
    final stored = _storedSession ?? await _sessionStore.read();
    if (stored == null || stored.isExpired) {
      await _clearLocalSession();
      throw const HDCAuthException(
        code: 'session_expired',
        message: 'Your HDC session has expired. Please sign in again.',
        statusCode: 401,
      );
    }

    final response = await _get(
      '/api/auth/session',
      token: stored.token,
    );
    if (response.statusCode == 401) {
      await _clearLocalSession();
      throw const HDCAuthException(
        code: 'session_expired',
        message: 'Your HDC session has expired. Please sign in again.',
        statusCode: 401,
      );
    }

    final body = _requireSuccessObject(response);
    final user = _requireObject(body, 'user');
    _storedSession = stored;
    _hydrate(user: user, expiresAt: stored.expiresAt);
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    if (sessionId == 'current' || sessionId == _currentSession?.id) {
      await signOut();
      return;
    }

    throw const HDCAuthException(
      code: 'remote_session_management_unavailable',
      message: 'Remote session management is not enabled in this beta yet.',
    );
  }

  Future<void> _clearLegacyPersistentSession() async {
    const legacyStore = SecureAuthSessionStore();
    try {
      final legacy = await legacyStore.read();
      if (legacy != null && !legacy.isExpired) {
        try {
          await _post('/api/auth/logout', token: legacy.token);
        } on Object {
          // The backend session remains bounded by server-side expiry.
        }
      }
      await legacyStore.clear();
    } on Object {
      // Legacy cleanup must not prevent the app from starting.
    }
  }

  Future<http.Response> _get(
    String path, {
    String? token,
  }) async {
    try {
      return await _client
          .get(
            _endpoint(path),
            headers: _headers(token: token),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const HDCAuthException(
        code: 'network_timeout',
        message: 'HDC authentication timed out. Please try again.',
      );
    } on http.ClientException {
      throw const HDCAuthException(
        code: 'network_unavailable',
        message: 'Could not reach HDC authentication. Check your connection.',
      );
    }
  }

  Future<http.Response> _post(
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    try {
      return await _client
          .post(
            _endpoint(path),
            headers: _headers(token: token),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const HDCAuthException(
        code: 'network_timeout',
        message: 'HDC authentication timed out. Please try again.',
      );
    } on http.ClientException {
      throw const HDCAuthException(
        code: 'network_unavailable',
        message: 'Could not reach HDC authentication. Check your connection.',
      );
    }
  }

  Map<String, String> _headers({String? token}) {
    return {
      'accept': 'application/json',
      'content-type': 'application/json',
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
    };
  }

  Uri _endpoint(String path) {
    final base = baseUri.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Map<String, dynamic> _requireSuccessObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponseError(response);
    }

    final decoded = _decodeObject(response.body);
    if (decoded == null) {
      throw const HDCAuthException(
        code: 'invalid_server_response',
        message: 'HDC authentication returned an invalid response.',
      );
    }
    return decoded;
  }

  Map<String, dynamic>? _decodeObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Map<String, dynamic> _requireObject(
    Map<String, dynamic> parent,
    String key,
  ) {
    final value = parent[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    throw const HDCAuthException(
      code: 'invalid_server_response',
      message: 'HDC authentication returned incomplete account data.',
    );
  }

  Never _throwResponseError(http.Response response) {
    final body = _decodeObject(response.body) ?? const <String, dynamic>{};
    final code = body['error'] is String ? body['error'] as String : 'request_failed';

    final message = switch (code) {
      'invalid_credentials' => 'Email or password is incorrect.',
      'email_already_registered' =>
        'That email address is already registered with HDC.',
      'too_many_attempts' =>
        'Too many attempts. Please wait before trying again.',
      'invalid_registration' =>
        'Complete the account details, recovery questions, and terms acceptance.',
      'weak_recovery_answers' =>
        'Recovery answers must be distinct and cannot repeat your name, email, or password.',
      'invalid_recovery_answers' =>
        'Complete all three recovery questions and try again.',
      'invalid_recovery_request' => 'Enter a valid email address.',
      'invalid_current_password' => 'The current password is incorrect.',
      'reset_link_invalid' =>
        'That password reset code is invalid, expired, or already used.',
      'invalid_password_reset' =>
        'Use a valid reset code and a password of 12 to 128 characters.',
      'unauthorized' => 'Your HDC session is no longer valid. Please sign in again.',
      _ when response.statusCode >= 500 =>
        'HDC authentication is temporarily unavailable. Please try again.',
      _ => 'Authentication request failed. Please try again.',
    };

    throw HDCAuthException(
      code: code,
      message: message,
      statusCode: response.statusCode,
    );
  }

  AccountIdentity _identityFromJson(Map<String, dynamic> user) {
    final id = user['id'];
    final displayName = user['displayName'];
    final email = user['email'];
    final publicMemberId = user['publicMemberId'];
    if (!isValidHdcAccountId(id) ||
        displayName is! String ||
        displayName.isEmpty) {
      throw const HDCAuthException(
        code: 'invalid_server_response',
        message: 'HDC authentication returned incomplete account data.',
      );
    }

    final platformRoles = <HDCPlatformRole>{};
    final rawPlatformRoles = user['platformRoles'] ?? user['roles'];
    if (rawPlatformRoles is List) {
      for (final rawRole in rawPlatformRoles) {
        final role = parseHDCPlatformRole(rawRole);
        if (role != null) platformRoles.add(role);
      }
    }

    final internalRoles = <HDCInternalRole>{};
    final rawInternalRoles = user['internalRoles'];
    if (rawInternalRoles is List) {
      for (final rawRole in rawInternalRoles) {
        final role = parseHDCInternalRole(rawRole);
        if (role != null) internalRoles.add(role);
      }
    }

    // One-release compatibility for the original mixed `roles` payload.
    // Internal codes found there are moved into the internal domain and can
    // never become platform capabilities.
    final rawLegacyRoles = user['roles'];
    if (rawLegacyRoles is List) {
      for (final rawRole in rawLegacyRoles) {
        final role = parseHDCInternalRole(rawRole);
        if (role != null) internalRoles.add(role);
      }
    }

    final now = DateTime.now();
    final createdAt = _parseDate(user['createdAt']) ?? now;
    final updatedAt = _parseDate(user['updatedAt']) ?? createdAt;
    final accountId = id as String;

    return AccountIdentity(
      id: accountId,
      publicMemberId: publicMemberId is String && publicMemberId.isNotEmpty
          ? publicMemberId
          : null,
      email: email is String && email.isNotEmpty ? email : null,
      displayName: displayName,
      status: _statusFromCode('${user['status'] ?? 'disabled'}'),
      platformRoles: Set<HDCPlatformRole>.unmodifiable(platformRoles),
      internalRoles: Set<HDCInternalRole>.unmodifiable(internalRoles),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  void _hydrate({
    required Map<String, dynamic> user,
    required DateTime expiresAt,
  }) {
    final identity = _identityFromJson(user);
    final now = DateTime.now();
    _currentIdentity = identity;
    _currentSession = AuthenticatedSession(
      id: 'current',
      userId: identity.id,
      issuedAt: now,
      expiresAt: expiresAt,
      lastSeenAt: now,
      revoked: false,
    );
  }

  DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  HDCAccountStatus _statusFromCode(String value) {
    switch (value.trim().toLowerCase()) {
      case 'active':
        return HDCAccountStatus.active;
      case 'locked':
      case 'suspended':
        return HDCAccountStatus.suspended;
      case 'deleted':
        return HDCAccountStatus.deleted;
      case 'pending_verification':
      case 'pendingverification':
        return HDCAccountStatus.pendingVerification;
      case 'disabled':
      default:
        return HDCAccountStatus.disabled;
    }
  }

  Future<void> _clearLocalSession() async {
    try {
      await _sessionStore.clear();
    } finally {
      _storedSession = null;
      _clearMemory();
    }
  }

  void _clearMemory({bool keepStoredSession = false}) {
    _currentIdentity = null;
    _currentSession = null;
    if (!keepStoredSession) _storedSession = null;
  }
}
