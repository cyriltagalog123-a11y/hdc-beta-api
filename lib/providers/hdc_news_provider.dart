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
  bool _disposed = false;
  int _bindingVersion = 0;
  int _publicGeneration = 0;
  int _adminGeneration = 0;

  HdcNewsProvider({required this.client});

  List<HdcNewsPost> get publicPosts => List.unmodifiable(_publicPosts);
  List<HdcNewsPost> get adminPosts => List.unmodifiable(_adminPosts);
  bool get loadingPublic => _loadingPublic;
  bool get loadingAdmin => _loadingAdmin;
  bool get saving => _saving;
  Object? get lastError => _lastError;

  bool get canManage {
    final identity = _identity;
    if (_disposed || identity == null) return false;
    return identity.internalRoles.any(
      (role) => role == HDCInternalRole.owner ||
          role == HDCInternalRole.superAdmin ||
          role == HDCInternalRole.admin,
    );
  }

  void bindIdentity(AccountIdentity? identity) {
    if (_disposed) return;
    if (_identity?.id == identity?.id &&
        setEquals(_identity?.internalRoles, identity?.internalRoles)) {
      return;
    }
    _identity = identity;
    _bindingVersion += 1;
    _adminPosts = const [];
    _loadingAdmin = false;
    _saving = false;
    _lastError = null;
    notifyListeners();
  }

  Future<void> loadPublic({bool force = false}) async {
    if (_disposed || (_loadingPublic && !force)) return;
    final api = client;
    if (api == null) {
      _lastError = const HdcWorkflowException(
        code: 'news_backend_unavailable',
        message: 'HDC news services are unavailable in this environment.',
      );
      notifyListeners();
      return;
    }
    final generation = ++_publicGeneration;
    _loadingPublic = true;
    _lastError = null;
    notifyListeners();
    try {
      final response = await api.getPublic('/api/news');
      if (!_disposed && generation == _publicGeneration) {
        _publicPosts = _decodePosts(response['posts']);
      }
    } on Object catch (error) {
      if (!_disposed && generation == _publicGeneration) {
        _lastError = error;
      }
    } finally {
      if (!_disposed && generation == _publicGeneration) {
        _loadingPublic = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadAdmin({bool force = false}) async {
    if ((_loadingAdmin && !force) || !canManage) return;
    final api = client;
    if (api == null) return;
    final binding = _bindingVersion;
    final generation = ++_adminGeneration;
    bool current() =>
        _isCurrent(binding) && generation == _adminGeneration;
    _loadingAdmin = true;
    _lastError = null;
    notifyListeners();
    try {
      final response = await api.get('/api/internal/news');
      if (current()) _adminPosts = _decodePosts(response['posts']);
    } on Object catch (error) {
      if (current()) _lastError = error;
    } finally {
      if (current()) {
        _loadingAdmin = false;
        notifyListeners();
      }
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
    String? recognitionConsentMethod,
    String? recognitionConsentScope,
    String? recognitionConsentReference,
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
    _ensureNoWrite();
    final binding = _bindingVersion;
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
        'recognitionConsentMethod': recognitionConsentMethod?.trim(),
        'recognitionConsentScope': recognitionConsentScope?.trim(),
        'recognitionConsentReference': recognitionConsentReference?.trim(),
      };
      if (id != null) payload['id'] = id;
      final response = id == null
          ? await api.post('/api/internal/news', body: payload)
          : await api.put('/api/internal/news', body: payload);
      _ensureCurrent(binding);
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
      await Future.wait([loadAdmin(force: true), loadPublic(force: true)]);
      _ensureCurrent(binding);
      return post;
    } on Object catch (error) {
      if (_isCurrent(binding)) _lastError = error;
      rethrow;
    } finally {
      if (_isCurrent(binding)) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  Future<void> deletePost(HdcNewsPost post) async {
    if (!canManage) return;
    if (post.status == HdcNewsStatus.published || post.everPublished) {
      throw const HdcWorkflowException(
        code: 'news_delete_not_allowed',
        message: 'Published history is retained. Only a never-published draft can be deleted.',
      );
    }
    final api = client;
    if (api == null) return;
    _ensureNoWrite();
    final binding = _bindingVersion;
    _saving = true;
    _lastError = null;
    notifyListeners();
    try {
      await api.delete('/api/internal/news?id=${Uri.encodeQueryComponent(post.id)}');
      _ensureCurrent(binding);
      await Future.wait([loadAdmin(force: true), loadPublic(force: true)]);
      _ensureCurrent(binding);
    } on Object catch (error) {
      if (_isCurrent(binding)) _lastError = error;
      rethrow;
    } finally {
      if (_isCurrent(binding)) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrent(int binding) => canManage && binding == _bindingVersion;

  void _ensureCurrent(int binding) {
    if (!_isCurrent(binding)) {
      throw const HdcWorkflowException(
        code: 'session_changed',
        message: 'Your account changed. Reopen news management.',
      );
    }
  }

  void _ensureNoWrite() {
    if (_saving) {
      throw const HdcWorkflowException(
        code: 'news_request_in_progress',
        message: 'Wait for the current news change to finish.',
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _bindingVersion += 1;
    _adminPosts = const [];
    super.dispose();
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
