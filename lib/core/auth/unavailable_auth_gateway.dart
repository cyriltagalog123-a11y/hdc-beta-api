import '../../models/account_identity.dart';
import '../../models/account_recovery.dart';
import '../../models/authenticated_session.dart';
import '../../models/privacy_request.dart';
import 'auth_gateway.dart';

class UnavailableAuthGateway implements AuthGateway {
  final Object reason;

  const UnavailableAuthGateway(this.reason);

  @override
  AccountIdentity? get currentIdentity => null;

  @override
  AuthenticatedSession? get currentSession => null;

  Never _unavailable() {
    throw StateError(
      'HDC authentication is temporarily unavailable. '
      'Guest browsing remains available.',
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refreshSession() async => _unavailable();

  @override
  Future<AccountIdentity> acceptCurrentLegalDocuments() async => _unavailable();

  @override
  Future<List<HDCPrivacyRequest>> listPrivacyRequests() async => _unavailable();

  @override
  Future<HDCPrivacyRequest> submitPrivacyRequest({
    required HDCPrivacyRequestType type,
    required String details,
  }) async => _unavailable();

  @override
  Future<void> requestPasswordReset({required String email}) async =>
      _unavailable();

  @override
  Future<List<AccountRecoveryQuestion>> startPasswordRecovery({
    required String email,
  }) async => _unavailable();

  @override
  Future<AccountRecoveryVerification> verifyRecoveryAnswers({
    required String email,
    required List<AccountRecoveryAnswer> answers,
  }) async => _unavailable();

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async => _unavailable();

  @override
  Future<void> updateRecoveryAnswers({
    required String currentPassword,
    required List<AccountRecoveryAnswer> recoveryAnswers,
  }) async => _unavailable();

  @override
  Future<void> revokeSession(String sessionId) async => _unavailable();

  @override
  Future<AccountIdentity> signIn({
    required String identifier,
    required String password,
  }) async => _unavailable();

  @override
  Future<AccountIdentity> signUp({
    required String email,
    required String password,
    required String displayName,
    required List<AccountRecoveryAnswer> recoveryAnswers,
    required bool termsAccepted,
    required bool privacyAcknowledged,
  }) async => _unavailable();

  @override
  Future<void> signOut() async {}
}
