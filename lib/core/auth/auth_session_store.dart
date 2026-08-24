import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_exception.dart';

class StoredAuthSession {
  final String token;
  final DateTime expiresAt;

  const StoredAuthSession({
    required this.token,
    required this.expiresAt,
  });

  bool get isExpired => !expiresAt.isAfter(DateTime.now());
}

abstract interface class AuthSessionStore {
  Future<StoredAuthSession?> read();

  Future<void> write(StoredAuthSession session);

  Future<void> clear();
}


class MemoryAuthSessionStore implements AuthSessionStore {
  StoredAuthSession? _session;

  @override
  Future<StoredAuthSession?> read() async => _session;

  @override
  Future<void> write(StoredAuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

class SecureAuthSessionStore implements AuthSessionStore {
  static const _tokenKey = 'hdc.auth.session_token';
  static const _expiresAtKey = 'hdc.auth.session_expires_at';

  final FlutterSecureStorage storage;

  const SecureAuthSessionStore({
    this.storage = const FlutterSecureStorage(),
  });

  @override
  Future<StoredAuthSession?> read() async {
    try {
      final token = await storage.read(key: _tokenKey);
      final expiresAtValue = await storage.read(key: _expiresAtKey);

      if (token == null || token.isEmpty || expiresAtValue == null) {
        if (token != null || expiresAtValue != null) {
          await clear();
        }
        return null;
      }

      final expiresAt = DateTime.tryParse(expiresAtValue)?.toLocal();
      if (expiresAt == null) {
        await clear();
        return null;
      }

      return StoredAuthSession(
        token: token,
        expiresAt: expiresAt,
      );
    } on HDCAuthException {
      rethrow;
    } on Object {
      throw const HDCAuthException(
        code: 'secure_storage_unavailable',
        message: 'Secure session storage is unavailable on this device.',
      );
    }
  }

  @override
  Future<void> write(StoredAuthSession session) async {
    try {
      await storage.write(key: _tokenKey, value: session.token);
      await storage.write(
        key: _expiresAtKey,
        value: session.expiresAt.toUtc().toIso8601String(),
      );
    } on Object {
      throw const HDCAuthException(
        code: 'secure_storage_unavailable',
        message: 'Secure session storage is unavailable on this device.',
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await storage.delete(key: _tokenKey);
      await storage.delete(key: _expiresAtKey);
    } on Object {
      throw const HDCAuthException(
        code: 'secure_storage_unavailable',
        message: 'Secure session storage is unavailable on this device.',
      );
    }
  }
}
