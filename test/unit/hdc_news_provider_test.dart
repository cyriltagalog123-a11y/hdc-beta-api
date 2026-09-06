import 'package:flutter_test/flutter_test.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/models/hdc_news_post.dart';
import 'package:hdc_app/providers/hdc_news_provider.dart';

AccountIdentity identityWith(HDCInternalRole role) {
  final now = DateTime(2026, 9, 6);
  return AccountIdentity(
    id: '123e4567-e89b-12d3-a456-426614174000',
    displayName: 'News Admin',
    status: HDCAccountStatus.active,
    platformRoles: const {HDCPlatformRole.customer},
    internalRoles: {role},
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('HdcNewsProvider authorization', () {
    test('owner can manage news', () {
      final provider = HdcNewsProvider(client: null)
        ..bindIdentity(identityWith(HDCInternalRole.owner));
      expect(provider.canManage, isTrue);
    });

    test('super admin can manage news', () {
      final provider = HdcNewsProvider(client: null)
        ..bindIdentity(identityWith(HDCInternalRole.superAdmin));
      expect(provider.canManage, isTrue);
    });

    test('approved admin can manage news', () {
      final provider = HdcNewsProvider(client: null)
        ..bindIdentity(identityWith(HDCInternalRole.admin));
      expect(provider.canManage, isTrue);
    });

    test('moderator cannot manage news', () {
      final provider = HdcNewsProvider(client: null)
        ..bindIdentity(identityWith(HDCInternalRole.moderator));
      expect(provider.canManage, isFalse);
    });

    test('guest or ordinary user cannot manage news', () {
      final provider = HdcNewsProvider(client: null);
      expect(provider.canManage, isFalse);
    });
  });

  test('recognition post model preserves public subject and consent', () {
    final post = HdcNewsPost.fromJson({
      'id': 'post-1',
      'kind': 'recognition',
      'title': 'Thank you',
      'summary': 'Recognition summary',
      'body': 'Recognition details',
      'status': 'published',
      'isPinned': true,
      'recognitionSubject': 'Example Supporter',
      'recognitionConsentConfirmed': true,
      'publishedAt': '2026-09-06T10:00:00Z',
      'updatedAt': '2026-09-06T10:00:00Z',
    });

    expect(post.kind, HdcNewsKind.recognition);
    expect(post.status, HdcNewsStatus.published);
    expect(post.recognitionSubject, 'Example Supporter');
    expect(post.recognitionConsentConfirmed, isTrue);
    expect(post.isPinned, isTrue);
  });
}
