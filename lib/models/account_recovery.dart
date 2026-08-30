import 'legal_document.dart';

const int hdcRecoveryQuestionVersion = 1;
const String hdcCurrentTermsVersion = hdcCurrentLegalVersion;

class AccountRecoveryQuestion {
  final String questionCode;
  final String prompt;

  const AccountRecoveryQuestion({
    required this.questionCode,
    required this.prompt,
  });

  factory AccountRecoveryQuestion.fromJson(Map<String, dynamic> json) {
    final code = json['questionCode'];
    final prompt = json['prompt'];
    if (code is! String ||
        code.isEmpty ||
        prompt is! String ||
        prompt.isEmpty) {
      throw const FormatException('Invalid HDC recovery question.');
    }
    return AccountRecoveryQuestion(questionCode: code, prompt: prompt);
  }
}

const List<AccountRecoveryQuestion> hdcRegistrationRecoveryQuestions = [
  AccountRecoveryQuestion(
    questionCode: 'first_meal',
    prompt: 'What was the first meal you learned to prepare by yourself?',
  ),
  AccountRecoveryQuestion(
    questionCode: 'childhood_nickname',
    prompt: 'What nickname did someone close to you use for you when you were young?',
  ),
  AccountRecoveryQuestion(
    questionCode: 'private_phrase',
    prompt:
        'Create a private recovery phrase that you do not use anywhere else.',
  ),
];

class AccountRecoveryAnswer {
  final String questionCode;
  final String answer;

  const AccountRecoveryAnswer({
    required this.questionCode,
    required this.answer,
  });

  Map<String, Object?> toJson() => {
    'questionCode': questionCode,
    'answer': answer,
  };
}

enum AccountRecoveryOutcome { verified, manualReviewSubmitted }

class AccountRecoveryVerification {
  final AccountRecoveryOutcome outcome;
  final String? resetToken;
  final DateTime? expiresAt;

  const AccountRecoveryVerification({
    required this.outcome,
    this.resetToken,
    this.expiresAt,
  });

  bool get isVerified =>
      outcome == AccountRecoveryOutcome.verified && resetToken != null;

  factory AccountRecoveryVerification.fromJson(Map<String, dynamic> json) {
    switch (json['result']) {
      case 'verified':
        final token = json['resetToken'];
        final expiresAt = json['expiresAt'] is String
            ? DateTime.tryParse(json['expiresAt'] as String)?.toLocal()
            : null;
        if (token is! String || token.isEmpty || expiresAt == null) {
          throw const FormatException('Invalid HDC recovery verification.');
        }
        return AccountRecoveryVerification(
          outcome: AccountRecoveryOutcome.verified,
          resetToken: token,
          expiresAt: expiresAt,
        );
      case 'manual_review_submitted':
        return const AccountRecoveryVerification(
          outcome: AccountRecoveryOutcome.manualReviewSubmitted,
        );
      default:
        throw const FormatException('Invalid HDC recovery result.');
    }
  }
}
