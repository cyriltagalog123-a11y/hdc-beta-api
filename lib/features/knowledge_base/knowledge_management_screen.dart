import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/hdc_workflow_api_client.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';
import '../../providers/hdc_community_provider.dart';

class KnowledgeManagementScreen extends StatefulWidget {
  const KnowledgeManagementScreen({super.key});

  @override
  State<KnowledgeManagementScreen> createState() =>
      _KnowledgeManagementScreenState();
}

class _KnowledgeManagementScreenState extends State<KnowledgeManagementScreen> {
  bool _loading = true;
  Object? _error;
  bool _canPublish = false;
  List<Map<String, dynamic>> _articles = const [];

  HdcWorkflowApiClient? get _client =>
      context.read<HdcCommunityProvider>().client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
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
      final data = await client.get('/api/internal/knowledge');
      final raw = data['articles'];
      if (!mounted) return;
      setState(() {
        _canPublish = data['canPublish'] == true;
        _articles = raw is List
            ? List.unmodifiable(
                raw.whereType<Map>().map(
                      (item) => Map<String, dynamic>.from(item),
                    ),
              )
            : const [];
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? article]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _KnowledgeEditorScreen(
          client: _client,
          article: article,
          canPublish: _canPublish,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _history(Map<String, dynamic> article) async {
    final client = _client;
    if (client == null) return;
    try {
      final id = Uri.encodeQueryComponent('${article['id'] ?? ''}');
      final data = await client.get('/api/internal/knowledge?view=history&id=$id');
      final raw = data['versions'];
      final versions = raw is List
          ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${article['publicArticleId'] ?? 'Knowledge'} history'),
          content: SizedBox(
            width: 620,
            child: versions.isEmpty
                ? const Text('No version history is available.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: versions.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, index) {
                      final item = versions[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text('${item['version'] ?? '?'}'),
                        ),
                        title: Text('${item['title'] ?? ''}'),
                        subtitle: Text(
                          '${_label('${item['workflowStatus'] ?? ''}')} • '
                          '${item['changeNote'] ?? ''}',
                        ),
                        trailing: item['publishedAt'] == null
                            ? null
                            : const Icon(Icons.public, color: HDCColors.success),
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
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _deleteDraft(Map<String, dynamic> article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete never-published draft?'),
        content: Text(
          'Delete ${article['publicArticleId'] ?? 'this article'}? '
          'Published knowledge cannot be hard-deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete Draft'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final client = _client;
      if (client == null) return;
      final id = Uri.encodeQueryComponent('${article['id'] ?? ''}');
      await client.delete('/api/internal/knowledge?id=$id');
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh knowledge management',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New Guide'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(HDCSpacing.lg),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HDCFlowHero(
                        eyebrow: _canPublish
                            ? 'KNOWLEDGE AUTHORITY • PUBLISH ENABLED'
                            : 'KNOWLEDGE AUTHORING • REVIEW ONLY',
                        title: 'Build reviewed HDC knowledge without editing code.',
                        description: _canPublish
                            ? 'Draft, review, publish, archive, and inspect immutable article history. Publishing changes the public and Nexus retrieval authority.'
                            : 'Create and revise drafts, then move them to review. Owner or Super Admin publication is required before a version becomes public or Nexus-authoritative.',
                        icon: Icons.library_books_outlined,
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                      const HDCCard(
                        color: HDCColors.surfaceInteractive,
                        child: Text(
                          'Publishing is intentionally stricter than editing. Every saved change becomes a version, but public readers stay on the last published version until an authorized publisher approves a newer one. Published history is retained.',
                          style: TextStyle(height: 1.5),
                        ),
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(36),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_error != null)
                        HDCEmptyState(
                          icon: Icons.error_outline,
                          title: 'Knowledge management unavailable',
                          description: '$_error',
                          actions: [
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      else if (_articles.isEmpty)
                        const HDCEmptyState(
                          icon: Icons.menu_book_outlined,
                          title: 'No knowledge articles yet',
                          description: 'Create the first reviewed HDC guide.',
                        )
                      else
                        for (final article in _articles) ...[
                          _KnowledgeAdminCard(
                            article: article,
                            onEdit: () => _edit(article),
                            onHistory: () => _history(article),
                            onDelete: article['everPublished'] == true
                                ? null
                                : () => _deleteDraft(article),
                          ),
                          const SizedBox(height: 12),
                        ],
                      const SizedBox(height: 90),
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
}

class _KnowledgeAdminCard extends StatelessWidget {
  final Map<String, dynamic> article;
  final VoidCallback onEdit;
  final VoidCallback onHistory;
  final VoidCallback? onDelete;

  const _KnowledgeAdminCard({
    required this.article,
    required this.onEdit,
    required this.onHistory,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = '${article['status'] ?? 'draft'}';
    final publicVisible = article['publicVisible'] == true;
    return HDCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${article['title'] ?? 'Knowledge guide'}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${article['publicArticleId'] ?? ''} • '
                      '${_label('${article['category'] ?? ''}')} • '
                      'working v${article['version'] ?? 1}',
                      style: const TextStyle(color: HDCColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Chip(label: Text(status.toUpperCase())),
            ],
          ),
          const SizedBox(height: 10),
          Text('${article['summary'] ?? ''}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('${article['safetyLevel'] ?? 'low'} safety')),
              if (publicVisible)
                Chip(
                  avatar: const Icon(Icons.public, size: 16),
                  label: Text('Public v${article['publishedVersion']}'),
                )
              else
                const Chip(
                  avatar: Icon(Icons.visibility_off_outlined, size: 16),
                  label: Text('Not public'),
                ),
              if (article['nexusReady'] == true)
                const Chip(
                  avatar: Icon(Icons.psychology_alt_outlined, size: 16),
                  label: Text('Nexus-ready'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit / New Version'),
              ),
              OutlinedButton.icon(
                onPressed: onHistory,
                icon: const Icon(Icons.history),
                label: const Text('Version History'),
              ),
              if (onDelete != null)
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Draft'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KnowledgeEditorScreen extends StatefulWidget {
  final HdcWorkflowApiClient? client;
  final Map<String, dynamic>? article;
  final bool canPublish;

  const _KnowledgeEditorScreen({
    required this.client,
    required this.article,
    required this.canPublish,
  });

  @override
  State<_KnowledgeEditorScreen> createState() => _KnowledgeEditorScreenState();
}

class _KnowledgeEditorScreenState extends State<_KnowledgeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _summary;
  late final TextEditingController _body;
  late final TextEditingController _steps;
  late final TextEditingController _tags;
  late final TextEditingController _safetyNotice;
  late final TextEditingController _escalation;
  late final TextEditingController _changeNote;
  late String _category;
  late String _safetyLevel;
  late String _status;
  late bool _nexusReady;
  late bool _featured;
  bool _saving = false;

  bool get _editing => widget.article != null;

  @override
  void initState() {
    super.initState();
    final article = widget.article ?? const <String, dynamic>{};
    _title = TextEditingController(text: '${article['title'] ?? ''}');
    _slug = TextEditingController(text: '${article['slug'] ?? ''}');
    _summary = TextEditingController(text: '${article['summary'] ?? ''}');
    _body = TextEditingController(text: '${article['body'] ?? ''}');
    _steps = TextEditingController(
      text: _asStringList(article['steps']).join('\n'),
    );
    _tags = TextEditingController(
      text: _asStringList(article['tags']).join(', '),
    );
    _safetyNotice = TextEditingController(
      text: '${article['safetyNotice'] ?? ''}',
    );
    _escalation = TextEditingController(
      text: '${article['escalationText'] ?? ''}',
    );
    _changeNote = TextEditingController();
    _category = '${article['category'] ?? 'pc_laptop'}';
    _safetyLevel = '${article['safetyLevel'] ?? 'low'}';
    _status = '${article['status'] ?? 'draft'}';
    if (!widget.canPublish && (_status == 'published' || _status == 'archived')) {
      _status = 'review';
    }
    _nexusReady = article['nexusReady'] != false;
    _featured = article['isFeatured'] == true;
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _summary.dispose();
    _body.dispose();
    _steps.dispose();
    _tags.dispose();
    _safetyNotice.dispose();
    _escalation.dispose();
    _changeNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final client = widget.client;
    if (client == null) return;
    setState(() => _saving = true);
    try {
      final body = <String, Object?>{
        if (_editing) 'id': widget.article!['id'],
        'title': _title.text,
        'slug': _slug.text,
        'category': _category,
        'summary': _summary.text,
        'body': _body.text,
        'steps': _steps.text
            .split('\n')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        'tags': _tags.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        'safetyLevel': _safetyLevel,
        'safetyNotice': _safetyNotice.text,
        'escalationText': _escalation.text,
        'nexusReady': _nexusReady,
        'isFeatured': _featured,
        'status': _status,
        'changeNote': _changeNote.text,
      };
      if (_editing) {
        await client.put('/api/internal/knowledge', body: body);
      } else {
        await client.post('/api/internal/knowledge', body: body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = widget.canPublish
        ? const ['draft', 'review', 'published', 'archived']
        : const ['draft', 'review'];
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Knowledge Guide' : 'New Knowledge Guide'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(HDCSpacing.lg),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_editing)
                        Text(
                          '${widget.article!['publicArticleId']} • '
                          'working v${widget.article!['version']}',
                          style: const TextStyle(
                            color: HDCColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (_editing) const SizedBox(height: 12),
                      TextFormField(
                        controller: _title,
                        maxLength: 180,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) => (value?.trim().length ?? 0) < 5
                            ? 'Use a clear guide title.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _slug,
                        maxLength: 140,
                        decoration: const InputDecoration(
                          labelText: 'Slug (optional on first save)',
                          hintText: 'windows-printer-not-detected',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: const {
                          'pc_laptop': 'PC & Laptop',
                          'phones_mobile': 'Phones & Mobile',
                          'pos_business_tech': 'POS & Business Tech',
                          'network_internet': 'Network & Internet',
                          'printers_peripherals': 'Printers & Peripherals',
                          'security_accounts': 'Security & Accounts',
                        }.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _category = value ?? _category),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _summary,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Summary'),
                        validator: (value) => (value?.trim().length ?? 0) < 10
                            ? 'Add a useful summary.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _body,
                        maxLength: 20000,
                        minLines: 5,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          labelText: 'Context / explanation',
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 20
                            ? 'Explain when and why to use this guide.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _steps,
                        minLines: 6,
                        maxLines: 14,
                        decoration: const InputDecoration(
                          labelText: 'Troubleshooting steps',
                          helperText: 'One step per line. Maximum 20 steps.',
                        ),
                        validator: (value) => (value ?? '')
                                .split('\n')
                                .any((item) => item.trim().isNotEmpty)
                            ? null
                            : 'Add at least one troubleshooting step.',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _tags,
                        decoration: const InputDecoration(
                          labelText: 'Search tags',
                          helperText: 'Comma separated, e.g. windows, printer, usb',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Safety and escalation',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _safetyLevel,
                        decoration: const InputDecoration(labelText: 'Safety level'),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                        ],
                        onChanged: (value) => setState(() => _safetyLevel = value ?? _safetyLevel),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _safetyNotice,
                        maxLength: 1200,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Safety boundary'),
                        validator: (value) => _safetyLevel != 'low' &&
                                (value?.trim().length ?? 0) < 10
                            ? 'Moderate/high-risk guides require a safety boundary.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _escalation,
                        maxLength: 1600,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Stop / escalation guidance',
                        ),
                        validator: (value) => _safetyLevel == 'high' &&
                                (value?.trim().length ?? 0) < 10
                            ? 'High-risk guides require escalation guidance.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _nexusReady,
                        onChanged: (value) => setState(() => _nexusReady = value),
                        title: const Text('Available to Nexus retrieval'),
                        subtitle: const Text(
                          'Only published versions are actually retrievable by Nexus.',
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _featured,
                        onChanged: (value) => setState(() => _featured = value),
                        title: const Text('Featured guide'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Workflow status'),
                        items: statuses
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(_label(status)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _status = value ?? _status),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _changeNote,
                        maxLength: 500,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Version change note',
                          hintText: 'What changed or why this version is being saved?',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!widget.canPublish)
                        const HDCCard(
                          color: HDCColors.surfaceInteractive,
                          child: Text(
                            'Your internal role can draft and review knowledge. Publishing and archiving require Owner or Super Admin authority.',
                            style: TextStyle(height: 1.45),
                          ),
                        ),
                      if (!widget.canPublish) const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving…' : 'Save Version'),
                      ),
                      const SizedBox(height: 32),
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
}

List<String> _asStringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => '$item'.trim()).where((item) => item.isNotEmpty).toList();
}

String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
