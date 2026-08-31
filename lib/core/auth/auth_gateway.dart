import '../../models/account_identity.dart';
import '../../models/account_recovery.dart';
import '../../models/authenticated_session.dart';
import '../../models/privacy_request.dart';

abstract interface class AuthGateway {
  AccountIdentity? get currentIdentity;
  AuthenticatedSession? get currentSession;

  Future<void> initialize();

  Future<AccountIdentity> signIn({
    required String identifier,
    required String password,
  });

  Future<AccountIdentity> signUp({
    required String email,
    required String password,
    required String displayName,
    required List<AccountRecoveryAnswer> recoveryAnswers,
    required bool termsAccepted,
    required bool privacyAcknowledged,
  });

  Future<AccountIdentity> acceptCurrentLegalDocuments();

  Future<List<HDCPrivacyRequest>> listPrivacyRequests();

  Future<HDCPrivacyRequest> submitPrivacyRequest({
    required HDCPrivacyRequestType type,
    required String details,
  });

  Future<void> signOut();

  Future<void> requestPasswordReset({required String email});

  Future<List<AccountRecoveryQuestion>> startPasswordRecovery({
    required String email,
  });

  Future<AccountRecoveryVerification> verifyRecoveryAnswers({
    required String email,
    required List<AccountRecoveryAnswer> answers,
  });

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  });

  Future<void> updateRecoveryAnswers({
    required String currentPassword,
    required List<AccountRecoveryAnswer> recoveryAnswers,
  });

  Future<void> refreshSession();

  Future<void> revokeSession(String sessionId);
}
