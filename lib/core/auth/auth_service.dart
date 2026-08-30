import '../../models/account_identity.dart';
import '../../models/account_recovery.dart';
import 'auth_gateway.dart';

class AuthService {
  final AuthGateway gateway;

  const AuthService({required this.gateway});

  Future<AccountIdentity> signIn({
    required String identifier,
    required String password,
  }) async {
    final normalizedIdentifier = identifier.trim().toLowerCase();

    if (!_looksLikeEmail(normalizedIdentifier)) {
      throw ArgumentError('Enter a valid email address.');
    }

    if (password.isEmpty) {
      throw ArgumentError('Password is required.');
    }

    final identity = await gateway.signIn(
      identifier: normalizedIdentifier,
      password: password,
    );

    if (!identity.isActive) {
      await gateway.signOut();
      throw StateError('This HDC account is not currently active.');
    }

    final session = gateway.currentSession;
    if (session == null || !session.isUsable) {
      await gateway.signOut();
      throw StateError('A valid HDC session was not established.');
    }

    return identity;
  }

  Future<AccountIdentity> signUp({
    required String email,
    required String password,
    required String displayName,
    required List<AccountRecoveryAnswer> recoveryAnswers,
    required bool termsAccepted,
    required bool privacyAcknowledged,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = displayName.trim();

    if (!_looksLikeEmail(normalizedEmail)) {
      throw ArgumentError('Enter a valid email address.');
    }

    if (password.length < 12 || password.length > 128) {
      throw ArgumentError('Password must contain 12 to 128 characters.');
    }

    if (normalizedName.length < 2 || normalizedName.length > 80) {
      throw ArgumentError('Display name must contain 2 to 80 characters.');
    }

    if (!termsAccepted || !privacyAcknowledged) {
      throw ArgumentError(
        'Accept the HDC Beta Terms and Privacy Notice to register.',
      );
    }

    _validateRecoveryAnswers(recoveryAnswers);

    return gateway.signUp(
      email: normalizedEmail,
      password: password,
      displayName: normalizedName,
      recoveryAnswers: recoveryAnswers,
      termsAccepted: termsAccepted,
      privacyAcknowledged: privacyAcknowledged,
    );
  }

  void _validateRecoveryAnswers(List<AccountRecoveryAnswer> answers) {
    if (answers.length != hdcRegistrationRecoveryQuestions.length) {
      throw ArgumentError('Answer all three account recovery questions.');
    }

    final expected = hdcRegistrationRecoveryQuestions
        .map((question) => question.questionCode)
        .toSet();
    final normalized = <String>{};
    final seenQuestions = <String>{};
    for (final answer in answers) {
      final value = answer.answer.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (!expected.contains(answer.questionCode) ||
          !seenQuestions.add(answer.questionCode) ||
          value.length < 4 ||
          value.length > 160) {
        throw ArgumentError(
          'Each recovery answer must contain 4 to 160 characters.',
        );
      }
      normalized.add(value);
    }
    if (seenQuestions.length != expected.length ||
        normalized.length != answers.length) {
      throw ArgumentError('Use a different answer for each recovery question.');
    }
  }

  bool _looksLikeEmail(String value) {
    final at = value.indexOf('@');
    final dot = value.lastIndexOf('.');
    return at > 0 && dot > at + 1 && dot < value.length - 1;
  }
}
