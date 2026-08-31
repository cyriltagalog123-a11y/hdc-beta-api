import 'package:flutter/foundation.dart';

import '../core/auth/auth_gateway.dart';
import '../core/auth/auth_service.dart';
import '../models/account_identity.dart';
import '../models/account_recovery.dart';
import '../models/privacy_request.dart';

class HDCAuthProvider extends ChangeNotifier {
  final AuthGateway gateway;
  late final AuthService _service = AuthService(gateway: gateway);

  bool _initialized = false;
  bool _isBusy = false;
  bool _guestMode = false;
  Object? _lastError;
  AccountIdentity? _identityOverride;

  HDCAuthProvider({required this.gateway});

  AccountIdentity? get identity => _identityOverride ?? gateway.currentIdentity;
  bool get authenticated => gateway.currentSession?.isUsable ?? false;
  bool get isBusy => _isBusy;
  bool get guestMode => _guestMode;
  Object? get lastError => _lastError;
  String? get currentUserId => identity?.id;
  String get displayName => identity?.displayName ?? 'Guest';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _isBusy = true;
    notifyListeners();
    try {
      await gateway.initialize();
      _identityOverride = null;
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<AccountIdentity> signIn({
    required String identifier,
    required String password,
  }) async {
    _setBusy(true);
    try {
      final result = await _service.signIn(
        identifier: identifier,
        password: password,
      );
      _identityOverride = null;
      _guestMode = false;
      _lastError = null;
      return result;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<AccountIdentity> signUp({
    required String email,
    required String password,
    required String displayName,
    required List<AccountRecoveryAnswer> recoveryAnswers,
    required bool termsAccepted,
    required bool privacyAcknowledged,
  }) async {
    _setBusy(true);
    try {
      final result = await _service.signUp(
        email: email,
        password: password,
        displayName: displayName,
        recoveryAnswers: recoveryAnswers,
        termsAccepted: termsAccepted,
        privacyAcknowledged: privacyAcknowledged,
      );
      _identityOverride = null;
      _guestMode = false;
      _lastError = null;
      return result;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<AccountIdentity> acceptCurrentLegalDocuments() async {
    _setBusy(true);
    try {
      final result = await gateway.acceptCurrentLegalDocuments();
      _identityOverride = null;
      _lastError = null;
      return result;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<List<HDCPrivacyRequest>> listPrivacyRequests() async {
    try {
      final requests = await gateway.listPrivacyRequests();
      _lastError = null;
      return requests;
    } on Object catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<HDCPrivacyRequest> submitPrivacyRequest({
    required HDCPrivacyRequestType type,
    required String details,
  }) async {
    _setBusy(true);
    try {
      final request = await gateway.submitPrivacyRequest(
        type: type,
        details: details,
      );
      _lastError = null;
      return request;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> requestPasswordReset(String email) async {
    _setBusy(true);
    try {
      await gateway.requestPasswordReset(email: email.trim().toLowerCase());
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<List<AccountRecoveryQuestion>> startPasswordRecovery(
    String email,
  ) async {
    _setBusy(true);
    try {
      final result = await gateway.startPasswordRecovery(
        email: email.trim().toLowerCase(),
      );
      _lastError = null;
      return result;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<AccountRecoveryVerification> verifyRecoveryAnswers({
    required String email,
    required List<AccountRecoveryAnswer> answers,
  }) async {
    _setBusy(true);
    try {
      final result = await gateway.verifyRecoveryAnswers(
        email: email.trim().toLowerCase(),
        answers: answers,
      );
      _lastError = null;
      return result;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    _setBusy(true);
    try {
      await gateway.resetPassword(
        resetToken: resetToken,
        newPassword: newPassword,
      );
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> updateRecoveryAnswers({
    required String currentPassword,
    required List<AccountRecoveryAnswer> recoveryAnswers,
  }) async {
    _setBusy(true);
    try {
      await gateway.updateRecoveryAnswers(
        currentPassword: currentPassword,
        recoveryAnswers: recoveryAnswers,
      );
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    _setBusy(true);
    try {
      await gateway.signOut();
      _identityOverride = null;
      _guestMode = false;
      _lastError = null;
    } finally {
      _setBusy(false);
    }
  }

  void continueAsGuest() {
    _guestMode = true;
    _lastError = null;
    notifyListeners();
  }

  void updateDisplayNameFromProfile(String displayName) {
    final current = identity;
    final normalized = displayName.trim();
    if (current == null ||
        normalized.length < 2 ||
        normalized == current.displayName) {
      return;
    }
    _identityOverride = current.copyWith(
      displayName: normalized,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> refreshIdentity() async {
    if (!authenticated || _isBusy) return;
    _setBusy(true);
    try {
      await gateway.refreshSession();
      _identityOverride = null;
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}
