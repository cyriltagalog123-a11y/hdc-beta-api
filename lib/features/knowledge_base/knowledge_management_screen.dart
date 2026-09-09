import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/hdc_workflow_api_client.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../providers/hdc_community_provider.dart';
import 'knowledge_editing.dart';
import 'knowledge_editor_screen.dart';

class KnowledgeManagementScreen extends StatefulWidget {
  const KnowledgeManagementScreen({super.key});

  @override
  State<KnowledgeManagementScreen> createState() =>
      _KnowledgeManagementScreenState();
}

class _KnowledgeManagementScreenState extends State<KnowledgeManagementScreen> {
  final _search = TextEditingController();
  Timer? _searchDelay;
  int _generation = 0;
  String _category = '';
  String _status = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _busy = false;
  bool _authorized = false;
  bool _canPublish = false;
  int? _nextOffset;
  Object? _error;
  List<Map<String, dynamic>> _articles = const [];

  HdcWorkflowApiClient? get _client =>
      context.read<HdcCommunityProvider>().client;
  bool get _actionsEnabled =>
      _authorized && !_loading && !_loadingMore && !_busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _queueSearch(String _) {
    _searchDelay?.cancel();
    ++_generation;
    setState(() => _loading = true);
    _searchDelay = Timer(const Duration(milliseconds: 350), () => _load());
  }

  Future<void> _load({bool more = false}) async {
    if (!mounted || (more && (_nextOffset == null || _loadingMore))) return;
    _searchDelay?.cancel();
    final generation = ++_generation;
    final offset = more ? _nextOffset! : 0;
    setState(() {
      _loading = !more;
      _loadingMore = more;
      _error = null;
    });
    try {
      final client = _client;
      if (client == null) {
        throw const HdcWorkflowException(
          code: 'knowledge_management_unavailable',
          message: 'Knowledge management services are unavailable.',
        );
      }
      final path = Uri(
        path: '/api/internal/knowledge',
        queryParameters: {
          if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
          if (_category.isNotEmpty) 'category': _category,
          if (_status.isNotEmpty) 'status': _status,
          'offset': '$offset',
          'limit': '50',
        },
      ).toString();
      final data = await client.get(path);
      if (!mounted || generation != _generation) return;
      final raw = data['articles'];
      final articles = raw is List
          ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item))
          : <Map<String, dynamic>>[];
      setState(() {
        _authorized = true;
        _canPublish = data['canPublish'] == true;
        // Another author may change ordering between page loads.
        _articles = {
          for (final article in [if (more) ..._articles, ...articles])
            '${article['id']}': article,
        }.values.toList();
        _nextOffset = data['hasMore'] == true
            ? (data['nextOffset'] as num?)?.toInt()
            : null;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      if (more &&
          error is HdcWorkflowException &&
          error.statusCode != 401 &&
          error.statusCode != 403) {
        _notice('$error');
      } else {
        setState(() {
          _authorized = false;
          _canPublish = false;
          _articles = const [];
          _nextOffset = null;
          _error = error;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit([Map<String, dynamic>? article]) async {
    if (!_actionsEnabled) return;
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => KnowledgeEditorScreen(
          client: _client,
          article: article,
          canPublish: _canPublish,
        ),
      ),
    );
    if (message != null && mounted) {
      await _load();
      _notice(message);
    }
  }

  Future<bool> _confirm(
    String title,
    String description,
    String action,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _action(Map<String, dynamic> article, String action) async {
    if (!_actionsEnabled) return;
    setState(() => _busy = true);
    try {
      final client = _client!;
      final id = Uri.encodeQueryComponent('${article['id']}');
      final title = '${article['title']}';
      final payload = knowledgeUpdatePayload(article);
      String message;
      switch (action) {
        case 'history':
          final data = await client.get(
            '/api/internal/knowledge?view=history&id=$id',
          );
          if (!mounted) return;
          final raw = data['versions'];
          final versions = raw is List
              ? raw.whereType<Map>().toList()
              : <Map>[];
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text('${article['publicArticleId']} history'),
              content: SizedBox(
                width: 620,
                child: versions.isEmpty
                    ? const Text('No saved versions yet.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: versions.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, index) {
                          final version = versions[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Version ${version['version']} · ${version['title']}',
                            ),
                            subtitle: Text(
                              '${knowledgeStatuses[version['workflowStatus']]} · '
                              '${version['changeNote'] ?? ''}\n'
                              '${knowledgeCategories[version['category']] ?? ''}',
                            ),
                            trailing: version['publishedAt'] == null
                                ? null
                                : const Tooltip(
                                    message: 'Published version',
                                    child: Icon(
                                      Icons.public,
                                      color: HDCColors.success,
                                    ),
                                  ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
          return;
        case 'move':
          final category = await showDialog<String>(
            context: context,
            builder: (_) => _MoveGuideDialog(article: article),
          );
          if (category == null || !mounted) return;
          payload['category'] = category;
          if (article['status'] == 'published') {
            payload['status'] = 'review';
          }
          payload['changeNote'] =
              'Moved from ${knowledgeCategories[article['category']]} '
              'to ${knowledgeCategories[category]}';
          message = article['publicVisible'] == true
              ? 'Move saved for review. Publish the guide to update its public category.'
              : 'Guide moved to ${knowledgeCategories[category]}.';
        case 'archive':
          if (!_canPublish ||
              !await _confirm(
                'Archive guide?',
                '“$title” will be removed from public search and Nexus. '
                    'Its link and version history will be retained. You can restore it later.',
                'Archive guide',
              )) {
            return;
          }
          payload['status'] = 'archived';
          payload['changeNote'] = 'Archived from Knowledge Management';
          message = 'Guide archived. Its history has been retained.';
        case 'restore':
          if (!_canPublish ||
              !await _confirm(
                'Restore guide?',
                article['everPublished'] == true
                    ? 'The last published version of “$title” will become public again. '
                          'Any newer working changes will remain in review.'
                    : '“$title” will return to drafts for editing.',
                'Restore guide',
              )) {
            return;
          }
          payload['status'] = article['everPublished'] == true
              ? 'review'
              : 'draft';
          payload['changeNote'] = 'Restored from archive';
          message = article['everPublished'] == true
              ? 'Last published version restored. Working changes remain in review.'
              : 'Guide restored to drafts.';
        case 'delete':
          if (article['everPublished'] == true ||
              !await _confirm(
                'Delete unpublished guide?',
                '“$title” has never been published. This permanently deletes '
                    'the guide and its draft history.',
                'Delete draft',
              )) {
            return;
          }
          if (!mounted) return;
          await client.delete('/api/internal/knowledge?id=$id');
          await _load();
          _notice('Unpublished guide deleted.');
          return;
        default:
          return;
      }
      if (!mounted) return;
      await client.put('/api/internal/knowledge', body: payload);
      await _load();
      _notice(message);
    } on Object catch (error) {
      _notice('$error');
      if (error is HdcWorkflowException && error.statusCode == 409) {
        await _load();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _filter({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: options.entries
        .map(
          (entry) => DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: _busy
        ? null
        : (value) {
            if (value == null) return;
            setState(() => onChanged(value));
            _load();
          },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Knowledge Management'),
      actions: [
        IconButton(
          tooltip: 'Refresh guides',
          onPressed: _loading || _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          if (!_busy) {
            await _load();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your guide library',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add helpful guides, update their steps, and organize them by category.',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _actionsEnabled ? () => _edit() : null,
                        icon: const Icon(Icons.add),
                        label: const Text('New guide'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    HDCCard(
                      child: Column(
                        children: [
                          TextField(
                            controller: _search,
                            enabled: !_busy,
                            maxLength: 180,
                            decoration: InputDecoration(
                              labelText: 'Find a guide',
                              hintText: 'Title, summary, tag, or guide ID',
                              counterText: '',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: IconButton(
                                tooltip: 'Clear search',
                                onPressed: _busy
                                    ? null
                                    : () {
                                        _search.clear();
                                        _load();
                                      },
                                icon: const Icon(Icons.close),
                              ),
                            ),
                            onChanged: _queueSearch,
                            onSubmitted: (_) => _load(),
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth < 620
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 16) / 2;
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  SizedBox(
                                    width: width,
                                    child: _filter(
                                      label: 'Category',
                                      value: _category,
                                      options: {
                                        '': 'All categories',
                                        ...knowledgeCategories,
                                      },
                                      onChanged: (value) => _category = value,
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child: _filter(
                                      label: 'Working status',
                                      value: _status,
                                      options: {
                                        '': 'All statuses',
                                        ...knowledgeStatuses,
                                      },
                                      onChanged: (value) => _status = value,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_authorized)
                      Text(
                        _canPublish
                            ? 'Save drafts privately, then publish when ready. Archive a published guide to remove it from readers.'
                            : 'You can create drafts and send updates for review. An Owner or Super Admin publishes or archives guides.',
                        style: const TextStyle(
                          color: HDCColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_busy) const LinearProgressIndicator(),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      HDCEmptyState(
                        icon: Icons.error_outline,
                        title: 'Guides could not be loaded',
                        description: '$_error',
                        actions: [
                          OutlinedButton(
                            onPressed: () => _load(),
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    else if (_articles.isEmpty)
                      HDCEmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'No guides found',
                        description: 'Try another search or category, or create a new guide.',
                        actions: [
                          TextButton(
                            onPressed: () {
                              _search.clear();
                              setState(() {
                                _category = '';
                                _status = '';
                              });
                              _load();
                            },
                            child: const Text('Clear filters'),
                          ),
                        ],
                      )
                    else ...[
                      Text(
                        '${_articles.length} guides${_nextOffset != null ? ' loaded · more available' : ''}',
                      ),
                      const SizedBox(height: 10),
                      for (final article in _articles) ...[
                        _GuideCard(
                          article: article,
                          enabled: _actionsEnabled,
                          canPublish: _canPublish,
                          onEdit: () => _edit(article),
                          onAction: (action) => _action(article, action),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_nextOffset != null)
                        OutlinedButton(
                          onPressed: _loadingMore || _busy
                              ? null
                              : () => _load(more: true),
                          child: Text(
                            _loadingMore ? 'Loading…' : 'Load more guides',
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GuideCard extends StatelessWidget {
  final Map<String, dynamic> article;
  final bool enabled;
  final bool canPublish;
  final VoidCallback onEdit;
  final ValueChanged<String> onAction;
  const _GuideCard({
    required this.article,
    required this.enabled,
    required this.canPublish,
    required this.onEdit,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final archived = article['status'] == 'archived';
    final visible = article['publicVisible'] == true;
    return HDCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${article['title']}',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${knowledgeCategories[article['category']]} · ${article['publicArticleId']}',
          ),
          const SizedBox(height: 8),
          Text(
            '${article['summary']}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                label: Text(
                  '${knowledgeStatuses[article['status']]} · v${article['version']}',
                ),
              ),
              Chip(
                label: Text(
                  visible
                      ? 'Public v${article['publishedVersion']}'
                      : 'Not public',
                ),
              ),
              if (article['isFeatured'] == true)
                const Chip(label: Text('Featured')),
            ],
          ),
          if (visible && article['version'] != article['publishedVersion'])
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Unpublished changes · readers still see the last published version.',
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!archived)
                FilledButton.tonalIcon(
                  onPressed: enabled ? onEdit : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit guide'),
                ),
              if (!archived)
                OutlinedButton.icon(
                  onPressed: enabled ? () => onAction('move') : null,
                  icon: const Icon(Icons.drive_file_move_outlined),
                  label: const Text('Move'),
                ),
              if (archived && canPublish)
                OutlinedButton.icon(
                  onPressed: enabled ? () => onAction('restore') : null,
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Restore guide'),
                ),
              PopupMenuButton<String>(
                enabled: enabled,
                tooltip: 'More actions for ${article['title']}',
                onSelected: onAction,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'history',
                    child: Text('Version history'),
                  ),
                  if (!archived &&
                      canPublish &&
                      article['everPublished'] == true)
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive guide'),
                    ),
                  if (!archived && article['everPublished'] != true)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete draft'),
                    ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('More ⋮'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoveGuideDialog extends StatefulWidget {
  final Map<String, dynamic> article;
  const _MoveGuideDialog({required this.article});
  @override
  State<_MoveGuideDialog> createState() => _MoveGuideDialogState();
}

class _MoveGuideDialogState extends State<_MoveGuideDialog> {
  late String _category = '${widget.article['category']}';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Move guide'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.article['title']}'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Destination category',
            ),
            items: knowledgeCategories.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 16),
          Text(
            widget.article['publicVisible'] == true
                ? 'This saves a review copy. The public category changes only when you publish the updated guide.'
                : 'The guide keeps its link, content, and version history.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _category == widget.article['category']
            ? null
            : () => Navigator.pop(context, _category),
        child: const Text('Save move'),
      ),
    ],
  );
}
