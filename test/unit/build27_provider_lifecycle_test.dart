import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/models/hdc_news_post.dart';
import 'package:hdc_app/models/platform_role_admin_member.dart';
import 'package:hdc_app/providers/hdc_community_provider.dart';
import 'package:hdc_app/providers/hdc_knowledge_provider.dart';
import 'package:hdc_app/providers/hdc_news_provider.dart';
import 'package:hdc_app/providers/platform_role_admin_provider.dart';

class _Call {
  final String method;
  final String path;
  final result = Completer<Map<String, dynamic>>();

  _Call(this.method, this.path);
}

class _DelayedApi extends HdcWorkflowApiClient {
  final calls = <_Call>[];

  _DelayedApi()
      : super(
          baseUri: Uri.parse('https://example.test'),
          sessionStore: MemoryAuthSessionStore(),
        );

  Future<Map<String, dynamic>> _enqueue(String method, String path) {
    final call = _Call(method, path);
    calls.add(call);
    return call.result.future;
  }

  @override
  Future<Map<String, dynamic>> get(String path) => _enqueue('GET', path);

  @override
  Future<Map<String, dynamic>> getPublic(String path) => _enqueue('PUBLIC', path);

  @override
  Future<Map<String, dynamic>> post(String path, {Map<String, Object?>? body}) =>
      _enqueue('POST', path);

  @override
  Future<Map<String, dynamic>> put(String path, {required Map<String, Object?> body}) =>
      _enqueue('PUT', path);

  @override
  Future<Map<String, dynamic>> delete(String path) => _enqueue('DELETE', path);
}

AccountIdentity _admin(String id, {bool authorized = true}) => AccountIdentity(
      id: id,
      displayName: id,
      status: HDCAccountStatus.active,
      platformRoles: const {HDCPlatformRole.customer},
      internalRoles: authorized ? const {HDCInternalRole.owner} : const {},
      createdAt: DateTime(2026, 9, 9),
      updatedAt: DateTime(2026, 9, 9),
    );

Map<String, dynamic> _post(String title) => {
      'id': 'news-1',
      'title': title,
      'status': 'draft',
      'updatedAt': '2026-09-09T00:00:00Z',
    };

Future<HdcNewsPost> _save(HdcNewsProvider provider) => provider.save(
      kind: HdcNewsKind.announcement,
      title: 'Updated news',
      summary: 'Summary',
      body: 'Body',
      status: HdcNewsStatus.draft,
      isPinned: false,
      recognitionConsentConfirmed: false,
    );

void main() {
  test('community ignores private responses from a previous login, even for the same user', () async {
    final api = _DelayedApi();
    final provider = HdcCommunityProvider(client: api)..bindUser('first');
    final old = provider.refreshAll();
    provider.bindUser(null);
    provider.bindUser('first');
    final current = provider.refreshAll();
    for (final call in api.calls.take(3)) {
      call.result.complete({
        'received': {'average': 5, 'count': 20},
        'suggestions': [{'title': 'Previous login'}],
        'badges': [{'key': 'previous'}],
      });
    }
    await old;
    expect(provider.receivedCount, 0);
    expect(provider.suggestions, isEmpty);
    expect(provider.badges, isEmpty);
    expect(provider.isLoading, isTrue);
    for (final call in api.calls.skip(3)) {
      call.result.complete({
        'received': {'average': 4, 'count': 1},
        'suggestions': [{'title': 'Current login'}],
        'badges': [{'key': 'current'}],
      });
    }
    await current;
    expect(provider.receivedCount, 1);
    expect(provider.suggestions.single.title, 'Current login');
    expect(provider.badges.single.key, 'current');
    expect(provider.isLoading, isFalse);
    provider.dispose();
  });

  test('community retains the newest results and ignores disposed errors', () async {
    final api = _DelayedApi();
    final provider = HdcCommunityProvider(client: api)..bindUser('first');
    final old = provider.refreshSuggestions();
    final current = provider.refreshSuggestions();
    api.calls[1].result.complete({'suggestions': [{'title': 'Newest'}]});
    await current;
    api.calls[0].result.complete({'suggestions': [{'title': 'Old'}]});
    await old;
    expect(provider.suggestions.single.title, 'Newest');
    final pending = provider.refreshAll();
    provider.dispose();
    for (final call in api.calls.skip(2)) {
      call.result.completeError(StateError('Late failure'));
    }
    await pending;
  });

  test('knowledge search clears failed counts and ignores disposed completion', () async {
    final api = _DelayedApi();
    final provider = HdcKnowledgeProvider(client: api);
    final initial = provider.search();
    api.calls.last.result.complete({'articles': [], 'categoryCounts': {'network': 3}});
    await initial;
    expect(provider.categoryCounts['network'], 3);
    final failed = provider.search(query: 'missing');
    api.calls.last.result.completeError(StateError('Unavailable'));
    await failed;
    expect(provider.categoryCounts, isEmpty);
    expect(provider.articles, isEmpty);
    final pending = provider.search();
    provider.dispose();
    api.calls.last.result.complete({'articles': [{'title': 'Late result'}]});
    await pending;
    expect(provider.articles, isEmpty);
  });

  test('community write does not refresh another account after completion', () async {
    final api = _DelayedApi();
    final provider = HdcCommunityProvider(client: api)..bindUser('first');
    final saving = provider.submitSuggestion(
      category: 'general',
      title: 'Suggestion',
      body: 'Details',
      publicAttributionConsent: false,
    );
    final result = expectLater(saving, throwsA(isA<HdcWorkflowException>().having(
      (error) => error.code, 'code', 'session_changed',
    )));
    provider.bindUser('second');
    api.calls.single.result.complete({});
    await result;
    expect(api.calls, hasLength(1));
    expect(provider.suggestions, isEmpty);
    provider.dispose();
  });

  test('news clears private drafts on account or role changes and ignores late responses', () async {
    final api = _DelayedApi();
    final provider = HdcNewsProvider(client: api)..bindIdentity(_admin('first'));
    final first = provider.loadAdmin();
    api.calls.last.result.complete({'posts': [_post('Private draft')]});
    await first;
    expect(provider.adminPosts, hasLength(1));
    final old = provider.loadAdmin();
    provider.bindIdentity(_admin('second'));
    expect(provider.adminPosts, isEmpty);
    final current = provider.loadAdmin();
    api.calls[1].result.complete({'posts': [_post('Old account')]});
    await old;
    expect(provider.adminPosts, isEmpty);
    expect(provider.loadingAdmin, isTrue);
    provider.bindIdentity(_admin('second', authorized: false));
    api.calls[2].result.complete({'posts': [_post('Revoked access')]});
    await current;
    expect(provider.adminPosts, isEmpty);
    expect(provider.loadingAdmin, isFalse);
    expect(provider.canManage, isFalse);
    provider.dispose();
  });

  test('news refresh after save supersedes reads started before the write', () async {
    final api = _DelayedApi();
    final provider = HdcNewsProvider(client: api)..bindIdentity(_admin('first'));
    final oldAdmin = provider.loadAdmin();
    final oldPublic = provider.loadPublic();
    final saving = _save(provider);
    await expectLater(_save(provider), throwsA(isA<HdcWorkflowException>().having(
      (error) => error.code, 'code', 'news_request_in_progress',
    )));
    expect(api.calls.where((call) => call.method == 'POST'), hasLength(1));
    api.calls[2].result.complete({'post': _post('Updated news')});
    await pumpEventQueue();
    expect(api.calls, hasLength(5));
    api.calls[3].result.complete({'posts': [_post('Updated news')]});
    api.calls[4].result.complete({'posts': [_post('Updated news')]});
    await saving;
    api.calls[0].result.complete({'posts': [_post('Old news')]});
    api.calls[1].result.complete({'posts': [_post('Old news')]});
    await Future.wait([oldAdmin, oldPublic]);
    expect(provider.adminPosts.single.title, 'Updated news');
    expect(provider.publicPosts.single.title, 'Updated news');
    expect(provider.saving, isFalse);
    provider.dispose();
  });

  test('news late write cannot refresh or change state after logout', () async {
    final api = _DelayedApi();
    final provider = HdcNewsProvider(client: api)..bindIdentity(_admin('first'));
    final saving = _save(provider);
    final result = expectLater(saving, throwsA(isA<HdcWorkflowException>().having(
      (error) => error.code, 'code', 'session_changed',
    )));
    provider.bindIdentity(null);
    expect(provider.saving, isFalse);
    api.calls.single.result.complete({'post': _post('Old write')});
    await result;
    expect(api.calls, hasLength(1));
    expect(provider.lastError, isNull);
    expect(provider.adminPosts, isEmpty);
    provider.dispose();
  });

  test('news pending public and admin requests do not notify after disposal', () async {
    final api = _DelayedApi();
    final provider = HdcNewsProvider(client: api)..bindIdentity(_admin('first'));
    final pending = Future.wait([provider.loadPublic(), provider.loadAdmin()]);
    provider.dispose();
    api.calls[0].result.complete({'posts': [_post('Late')]});
    api.calls[1].result.completeError(StateError('Late failure'));
    await pending;
    expect(provider.publicPosts, isEmpty);
    expect(provider.adminPosts, isEmpty);
  });

  test('role search retains the latest query and ignores results after access revocation', () async {
    final api = _DelayedApi();
    final provider = PlatformRoleAdminProvider(client: api)..bindIdentity(_admin('first'));
    final old = provider.search('old');
    final current = provider.search('new');
    api.calls[1].result.complete({'members': [{'id': 'new', 'displayName': 'Current'}]});
    await current;
    api.calls[0].result.complete({'members': [{'id': 'old', 'displayName': 'Previous'}]});
    await old;
    expect(provider.members.single.id, 'new');
    final pending = provider.search();
    provider.bindIdentity(_admin('first', authorized: false));
    api.calls.last.result.completeError(StateError('Late failure'));
    await pending;
    expect(provider.members, isEmpty);
    expect(provider.lastError, isNull);
    expect(provider.isLoading, isFalse);
    provider.dispose();
  });

  test('role change cannot update another account or notify after disposal', () async {
    final api = _DelayedApi();
    final provider = PlatformRoleAdminProvider(client: api)..bindIdentity(_admin('first'));
    final saving = provider.changeRole(
      member: PlatformRoleAdminMember.fromJson({'id': 'member'}),
      role: HDCPlatformRole.technician,
      assign: true,
      reason: 'Approved',
    );
    final result = expectLater(saving, throwsA(isA<StateError>()));
    provider.bindIdentity(_admin('second'));
    expect(provider.isSaving, isFalse);
    final pending = provider.search();
    provider.dispose();
    api.calls[0].result.complete({'member': {'id': 'member', 'platformRoles': ['technician']}});
    api.calls[1].result.complete({'members': [{'id': 'late'}]});
    await result;
    await pending;
    expect(provider.members, isEmpty);
    expect(provider.lastError, isNull);
  });

  test('role changes apply server authority once and supersede pending searches', () async {
    final api = _DelayedApi();
    final provider = PlatformRoleAdminProvider(client: api)..bindIdentity(_admin('first'));
    final initial = provider.search();
    final member = {'id': 'member', 'platformRoles': ['customer']};
    api.calls.single.result.complete({'members': [member]});
    await initial;
    final oldSearch = provider.search();
    Future<void> assignRole() => provider.changeRole(
      member: provider.members.single,
      role: HDCPlatformRole.technician,
      assign: true,
      reason: 'Approved',
    );
    final saving = assignRole();
    await expectLater(assignRole(), throwsA(isA<StateError>()));
    expect(api.calls.where((call) => call.method == 'PUT'), hasLength(1));
    api.calls[2].result.complete({'member': {
      ...member, 'platformRoles': ['customer', 'technician'],
    }});
    await saving;
    api.calls[1].result.complete({'members': [member]});
    await oldSearch;
    expect(provider.members.single.platformRoles, contains(HDCPlatformRole.technician));
    expect(provider.isSaving, isFalse);
    expect(provider.isLoading, isFalse);
    provider.dispose();
  });
}
