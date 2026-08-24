enum PrivateMessageModerationAction {
  allow,
  warn,
  block,
}

class PrivateMessageModerationResult {
  final PrivateMessageModerationAction action;
  final String? reason;

  const PrivateMessageModerationResult({
    required this.action,
    this.reason,
  });

  bool get requiresWarning =>
      action == PrivateMessageModerationAction.warn;

  bool get isBlocked =>
      action == PrivateMessageModerationAction.block;
}

class PrivateMessageModerationService {
  static const _profanityTokens = <String>{
    'fuck',
    'fucking',
    'shit',
    'bullshit',
    'bitch',
    'asshole',
    'motherfucker',
    'puta',
    'putangina',
    'tangina',
    'gago',
    'ulol',
  };

  static const _blockedPatterns = <String>[
    'i will kill you',
    'i am going to kill you',
    'send me your password',
    'give me your password',
    'send your otp',
    'give me your otp',
  ];

  const PrivateMessageModerationService();

  PrivateMessageModerationResult assess(String text) {
    final normalized = text.trim().toLowerCase();

    if (normalized.isEmpty) {
      return const PrivateMessageModerationResult(
        action: PrivateMessageModerationAction.block,
        reason: 'Message cannot be empty.',
      );
    }

    for (final pattern in _blockedPatterns) {
      if (normalized.contains(pattern)) {
        return const PrivateMessageModerationResult(
          action: PrivateMessageModerationAction.block,
          reason:
              'This message contains content HDC will not send in private chat.',
        );
      }
    }

    final words = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty);

    if (words.any(_profanityTokens.contains)) {
      return const PrivateMessageModerationResult(
        action: PrivateMessageModerationAction.warn,
        reason:
            'This message contains language that may be offensive.',
      );
    }

    return const PrivateMessageModerationResult(
      action: PrivateMessageModerationAction.allow,
    );
  }
}
