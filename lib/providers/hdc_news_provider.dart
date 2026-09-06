import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';
import '../models/account_identity.dart';
import '../models/hdc_news_post.dart';

class HdcNewsProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;

  AccountIdentity? _identity;
  List<HdcNewsPost> _publicPosts = const [];
  List<HdcNewsPost> _adminPosts = const [];
  bool _loadingPublic = false;
  bool _loadingAdmin = false;
  bool _saving = false;
  Object? _lastError;

  HdcNewsProvider({required this.client});

  List<HdcNewsPost> get publicPosts => List.unmodifiable(_publicPosts);
  List<HdcNewsPost> get adminPosts => List.unmodifiable(_adminPosts);
  bool get loadingPublic => _loadingPublic;
  bool get loadingAdmin => _loadingAdmin;
  bool get saving => _saving;
  Object? get lastError => _lastError;

  bool get canManage {
    final identity = _identity;
    if (identity == null) return false;
    return identity.internalRoles.any(
      (role) => role == HDCInternalRole.owner ||
          role == HDCInternalRole.superAdmin ||
          role == HDCInternalRole.admin,
    );
  }

  void bindIdentity(AccountIdentity? identity) {
    if (_identity?.id == identity?.id &&
        setEquals(_identity?.internalRoles, identity?.internalRoles)) {
      return;
    }
    _identity = identity;
    if (!canManage) _adminPosts = const [];
    notifyListeners();
  }

  Future<void> loadPublic() async {
    if (_loadingPublic) return;
    final api = client;
    if (api == null) {
      _lastError = const HdcWorkflowException(
        code: 'news_backend_unavailable',
        message: 'HDC news services are unavailable in this environment.',
      );
      notifyListeners();
      return;
    }
    _loadingPublic = true;
    _lastError = null;
    notifyListeners();
    try {
      final response = await api.getPublic('/api/news');
      _publicPosts = _decodePosts(response['posts']);
    } on Object catch (error) {
      _lastError = error;
    } finally {
      _loadingPublic = false;
      notifyListeners();
    }
  }

  Future<void> loadAdmin() async {
    if (_loadingAdmin || !canManage) return;
    final api = client;
    if (api == null) return;
    _loadingAdmin = true;
    _lastError = null;
    notifyListeners();
    try {
      final response = await api.get('/api/internal/news');
      _adminPosts = _decodePosts(response['posts']);
    } on Object catch (error) {
      _lastError = error;
    } finally {
      _loadingAdmin = false;
      notifyListeners();
    }
  }

  Future<HdcNewsPost> save({
    String? id,
    required HdcNewsKind kind,
    required String title,
    required String summary,
    required String body,
    required HdcNewsStatus status,
    required bool isPinned,
    String? recognitionSubject,
    required bool recognitionConsentConfirmed,
  }) async {
    if (!canManage) {
      throw const HdcWorkflowException(
        code: 'news_management_forbidden',
        message: 'Owner or approved admin access is required.',
        statusCode: 403,
      );
    }
    final api = client;
    if (api == null) {
      throw const HdcWorkflowException(
        code: 'news_backend_unavailable',
        message: 'HDC news services are unavailable in this environment.',
      );
    }
    _saving = true;
    _lastError = null;
    notifyListeners();
    try {
      final payload = <String, Object?>{
        'kind': kind.code,
        'title': title.trim(),
        'summary': summary.trim(),
        'body': body.trim(),
        'status': status.code,
        'isPinned': isPinned,
        'recognitionSubject': recognitionSubject?.trim(),
        'recognitionConsentConfirmed': recognitionConsentConfirmed,
      };
      if (id != null) payload['id'] = id;
      final response = id == null
          ? await api.post('/api/internal/news', body: payload)
          : await api.put('/api/internal/news', body: payload);
      final rawPost = response['post'];
      if (rawPost is! Map) {
        throw const HdcWorkflowException(
          code: 'invalid_server_response',
          message: 'HDC returned an invalid news response.',
        );
      }
      final post = HdcNewsPost.fromJson(
        rawPost.map((key, value) => MapEntry('$key', value)),
      );
      await Future.wait([loadAdmin(), loadPublic()]);
      return post;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> deletePost(HdcNewsPost post) async {
    if (!canManage) return;
    if (post.status == HdcNewsStatus.published) {
      throw const HdcWorkflowException(
        code: 'news_delete_not_allowed',
        message: 'Archive a published post before deleting it.',
      );
    }
    final api = client;
    if (api == null) return;
    _saving = true;
    _lastError = null;
    notifyListeners();
    try {
      await api.delete('/api/internal/news?id=${Uri.encodeQueryComponent(post.id)}');
      await Future.wait([loadAdmin(), loadPublic()]);
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  List<HdcNewsPost> _decodePosts(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (entry) => HdcNewsPost.fromJson(
            entry.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }
}
