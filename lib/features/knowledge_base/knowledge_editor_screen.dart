import 'package:flutter/material.dart';

import '../../core/api/hdc_workflow_api_client.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import 'knowledge_editing.dart';

class KnowledgeEditorScreen extends StatefulWidget {
  final HdcWorkflowApiClient? client;
  final Map<String, dynamic>? article;
  final bool canPublish;

  const KnowledgeEditorScreen({
    super.key,
    required this.client,
    required this.article,
    required this.canPublish,
  });

  @override
  State<KnowledgeEditorScreen> createState() => _KnowledgeEditorScreenState();
}

class _KnowledgeEditorScreenState extends State<KnowledgeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _steps = <TextEditingController>[];
  // Removed steps stay alive until the editor closes, allowing Undo safely.
  final _allSteps = <TextEditingController>[];
  late String _category;
  late String _safetyLevel;
  late bool _nexusReady;
  late bool _featured;
  bool _saving = false;
  bool _dirty = false;
  bool _allowLeave = false;
  bool _leaving = false;
  Object? _error;

  bool get _editing => widget.article != null;

  @override
  void initState() {
    super.initState();
    final article = widget.article ?? const <String, dynamic>{};
    for (final key in [
      'title',
      'slug',
      'summary',
      'body',
      'safetyNotice',
      'escalationText',
    ]) {
      _fields[key] = TextEditingController(text: '${article[key] ?? ''}');
    }
    _fields['tags'] = TextEditingController(
      text: knowledgeStringList(article['tags']).join(', '),
    );
    _fields['changeNote'] = TextEditingController();
    final steps = knowledgeStringList(article['steps']);
    for (final step in steps.isEmpty ? [''] : steps) {
      final controller = TextEditingController(text: step);
      _steps.add(controller);
      _allSteps.add(controller);
    }
    _category = '${article['category'] ?? 'pc_laptop'}';
    _safetyLevel = '${article['safetyLevel'] ?? 'low'}';
    _nexusReady = article['nexusReady'] != false;
    _featured = article['isFeatured'] == true;
  }

  @override
  void dispose() {
    for (final controller in [..._fields.values, ..._allSteps]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _leave() async {
    if (_saving || _leaving) return;
    _leaving = true;
    final discard =
        !_dirty ||
        await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Discard unsaved changes?'),
                content: const Text(
                  'Your changes have not been saved. Keep editing to save a draft first.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Keep editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Discard changes'),
                  ),
                ],
              ),
            ) ==
            true;
    _leaving = false;
    if (!discard || !mounted) return;
    setState(() => _allowLeave = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Map<String, Object?> _payload(String status) => {
    if (_editing) 'id': widget.article!['id'],
    if (_editing) 'expectedVersion': widget.article!['version'],
    for (final entry in _fields.entries)
      if (entry.key != 'tags') entry.key: entry.value.text.trim(),
    'category': _category,
    'steps': _steps.map((step) => step.text.trim()).toList(),
    'tags': _fields['tags']!.text
        .split(',')
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(),
    'safetyLevel': _safetyLevel,
    'nexusReady': _nexusReady,
    'isFeatured': _featured,
    'status': status,
  };

  Future<void> _save(String status) async {
    if (_saving ||
        _allowLeave ||
        (status == 'published' && !widget.canPublish)) {
      return;
    }
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      await Scrollable.ensureVisible(
        invalid.first.context,
        alignment: 0.15,
        duration: const Duration(milliseconds: 250),
      );
      return;
    }
    final client = widget.client;
    if (client == null) {
      setState(
        () => _error = 'Knowledge management services are unavailable. Your edits are still here.',
      );
      return;
    }
    // Block additional saves and edits while confirming publication as well.
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (status == 'published') {
        final publish = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Publish this version?'),
            content: Text(
              '“${_fields['title']!.text.trim()}” will become public in '
              '${knowledgeCategories[_category]}. '
              '${_nexusReady ? 'Nexus will also be able to retrieve this version. ' : ''}'
              'Previous versions will remain in history.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Publish guide'),
              ),
            ],
          ),
        );
        if (publish != true || !mounted) return;
      }
      final payload = _payload(status);
      if (_editing) {
        await client.put('/api/internal/knowledge', body: payload);
      } else {
        await client.post('/api/internal/knowledge', body: payload);
      }
      if (!mounted) return;
      setState(() => _allowLeave = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop(switch (status) {
        'published' => 'Guide published.',
        'review' => 'Guide saved for review. Public content changes only after publication.',
        _ => 'Draft saved. Public content has not changed.',
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted && !_allowLeave) setState(() => _saving = false);
    }
  }

  void _addStep() {
    if (_saving || _steps.length >= 20) return;
    final controller = TextEditingController();
    setState(() {
      _steps.add(controller);
      _allSteps.add(controller);
      _dirty = true;
    });
  }

  void _moveStep(int index, int direction) {
    final target = index + direction;
    if (_saving || target < 0 || target >= _steps.length) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _steps.insert(target, _steps.removeAt(index));
      _dirty = true;
    });
  }

  void _removeStep(int index) {
    if (_saving || _steps.length <= 1) return;
    final removed = _steps[index];
    FocusScope.of(context).unfocus();
    setState(() {
      _steps.removeAt(index);
      _dirty = true;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Step ${index + 1} removed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted ||
                _saving ||
                _steps.length >= 20 ||
                _steps.contains(removed)) {
              return;
            }
            setState(() {
              _steps.insert(index.clamp(0, _steps.length), removed);
              _dirty = true;
            });
          },
        ),
      ),
    );
  }

  Future<void> _preview() async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _GuidePreview(payload: _payload('draft')),
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    required int maxLength,
    int minLength = 0,
    int minLines = 1,
    int maxLines = 1,
    String? hint,
    String? helper,
    String? Function(String?)? validator,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('guide-$key'),
      controller: _fields[key],
      enabled: enabled,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 4,
        errorMaxLines: 4,
      ),
      validator:
          validator ??
          (value) => (value?.trim().length ?? 0) < minLength
              ? 'Enter at least $minLength characters.'
              : null,
    ),
  );

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: HDCColors.textSecondary)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope<String>(
    canPop: _allowLeave || (!_dirty && !_saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        _leave();
      }
    },
    child: Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit guide' : 'New guide')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$_error\nYour edits are still here.',
                    style: const TextStyle(color: HDCColors.danger),
                  ),
                ),
              if (_saving) const LinearProgressIndicator(),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _preview,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Preview'),
                  ),
                  FilledButton.tonal(
                    onPressed: _saving ? null : () => _save('draft'),
                    child: const Text('Save draft'),
                  ),
                  OutlinedButton(
                    onPressed: _saving ? null : () => _save('review'),
                    child: const Text('Send for review'),
                  ),
                  if (widget.canPublish)
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save('published'),
                      icon: const Icon(Icons.publish),
                      label: const Text('Publish…'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            onChanged: _changed,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HDCCard(
                        color: HDCColors.surfaceInteractive,
                        child: Text(
                          _editing
                              ? '${widget.article!['publicArticleId']} · working version ${widget.article!['version']}\n'
                                    '${widget.article!['publicVisible'] == true ? 'Readers currently see published version ${widget.article!['publishedVersion']}. ' : ''}'
                                    'Save changes privately, preview them, then publish when ready.'
                              : 'Start with a title, a short summary, and clear steps. Save a draft at any time once the required fields are complete.',
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                      _heading(
                        'Guide details',
                        'Help readers recognize their problem quickly.',
                      ),
                      _field(
                        'title',
                        'Title',
                        maxLength: 180,
                        minLength: 5,
                        hint: 'For example: USB printer is not detected',
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: knowledgeCategories.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _category = value ?? _category);
                          _changed();
                        },
                      ),
                      const SizedBox(height: 16),
                      _field(
                        'summary',
                        'Short summary',
                        maxLength: 500,
                        minLength: 10,
                        minLines: 2,
                        maxLines: 4,
                      ),
                      _field(
                        'body',
                        'When to use this guide',
                        maxLength: 20000,
                        minLength: 20,
                        minLines: 4,
                        maxLines: 12,
                        hint: 'Describe the symptoms, what the reader needs, and what this guide covers.',
                      ),
                      _heading(
                        'Troubleshooting steps',
                        'Add up to 20 steps. Use the arrows to put them in the right order.',
                      ),
                      for (var index = 0; index < _steps.length; index++)
                        Padding(
                          key: ObjectKey(_steps[index]),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: HDCCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Step ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Wrap(
                                      children: [
                                        IconButton(
                                          tooltip: 'Move step ${index + 1} up',
                                          onPressed: index == 0
                                              ? null
                                              : () => _moveStep(index, -1),
                                          icon: const Icon(Icons.arrow_upward),
                                        ),
                                        IconButton(
                                          tooltip:
                                              'Move step ${index + 1} down',
                                          onPressed: index == _steps.length - 1
                                              ? null
                                              : () => _moveStep(index, 1),
                                          icon: const Icon(
                                            Icons.arrow_downward,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remove step ${index + 1}',
                                          onPressed: _steps.length == 1
                                              ? null
                                              : () => _removeStep(index),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                TextFormField(
                                  controller: _steps[index],
                                  minLines: 2,
                                  maxLines: 6,
                                  maxLength: 700,
                                  decoration: InputDecoration(
                                    labelText: 'Step ${index + 1} instructions',
                                    hintText:
                                        'Give the reader one clear action.',
                                    errorMaxLines: 3,
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if (text.isEmpty)
                                      return 'Write this step or remove it.';
                                    if (text.length > 700)
                                      return 'Keep each step within 700 characters.';
                                    if (_steps
                                            .where(
                                              (step) =>
                                                  step.text.trim() == text,
                                            )
                                            .length >
                                        1) {
                                      return 'Combine duplicate steps or make each step distinct.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _steps.length >= 20 ? null : _addStep,
                          icon: const Icon(Icons.add),
                          label: Text('Add step (${_steps.length}/20)'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _heading(
                        'Safety and escalation',
                        'Tell readers when to stop and ask for qualified help.',
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _safetyLevel,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Safety level',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(
                            value: 'moderate',
                            child: Text('Moderate'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                        ],
                        onChanged: (value) {
                          setState(() => _safetyLevel = value ?? _safetyLevel);
                          _changed();
                        },
                      ),
                      const SizedBox(height: 16),
                      _field(
                        'safetyNotice',
                        'Safety boundary',
                        maxLength: 1200,
                        minLines: 2,
                        maxLines: 5,
                        validator: (value) =>
                            _safetyLevel != 'low' &&
                                (value?.trim().length ?? 0) < 10
                            ? 'Moderate and high-risk guides need a safety boundary.'
                            : null,
                      ),
                      _field(
                        'escalationText',
                        'When to stop and escalate',
                        maxLength: 1600,
                        minLines: 2,
                        maxLines: 5,
                        validator: (value) =>
                            _safetyLevel == 'high' &&
                                (value?.trim().length ?? 0) < 10
                            ? 'High-risk guides need escalation guidance.'
                            : null,
                      ),
                      _heading(
                        'Discovery',
                        'Help people find this guide in the Knowledge Base.',
                      ),
                      _field(
                        'tags',
                        'Search tags',
                        maxLength: 798,
                        helper: 'Separate tags with commas. Up to 16 tags, 48 characters each.',
                        hint: 'windows, printer, usb',
                        validator: (value) {
                          final tags = (value ?? '')
                              .split(',')
                              .map((tag) => tag.trim())
                              .where((tag) => tag.isNotEmpty)
                              .toList();
                          if (tags.length > 16)
                            return 'Use no more than 16 tags.';
                          if (tags.any((tag) => tag.length > 48))
                            return 'Keep each tag within 48 characters.';
                          return null;
                        },
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _featured,
                        title: const Text('Featured guide'),
                        onChanged: (value) {
                          setState(() => _featured = value);
                          _changed();
                        },
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _nexusReady,
                        title: const Text('Available to Nexus retrieval'),
                        subtitle: const Text(
                          'Takes effect only after publication.',
                        ),
                        onChanged: (value) {
                          setState(() => _nexusReady = value);
                          _changed();
                        },
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Guide link'),
                        subtitle: const Text(
                          'Created automatically from the title on first save.',
                        ),
                        children: [
                          _field(
                            'slug',
                            'Link name',
                            maxLength: 120,
                            enabled: widget.article?['everPublished'] != true,
                            helper: widget.article?['everPublished'] == true
                                ? 'Published links are permanent.'
                                : 'Optional. Leave blank to use the title.',
                            validator: (value) {
                              final slug = value?.trim() ?? '';
                              if (slug.isEmpty) return null;
                              return slug.length < 3 ||
                                      !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')
                                          .hasMatch(slug)
                                  ? 'Use at least 3 lowercase letters or numbers, separated by single hyphens.'
                                  : null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _field(
                        'changeNote',
                        'What changed? (optional)',
                        maxLength: 500,
                        minLines: 2,
                        maxLines: 3,
                        hint: 'For example: Added a Windows 11 step and clarified the safety note.',
                      ),
                      if (!widget.canPublish)
                        const Text(
                          'An Owner or Super Admin must approve publication. '
                          'Send for review when your guide is ready.',
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _GuidePreview extends StatelessWidget {
  final Map<String, Object?> payload;
  const _GuidePreview({required this.payload});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Preview guide')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('UNSAVED PREVIEW · only you can see this'),
                const SizedBox(height: 12),
                Text(
                  '${payload['title']}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${knowledgeCategories[payload['category']]} · ${payload['safetyLevel']} safety',
                ),
                const SizedBox(height: 16),
                SelectableText(
                  '${payload['summary']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if ('${payload['safetyNotice']}'.trim().isNotEmpty) ...[
                  _section(
                    context,
                    'Safety boundary',
                    '${payload['safetyNotice']}',
                  ),
                  const SizedBox(height: 16),
                ],
                _section(
                  context,
                  'When to use this guide',
                  '${payload['body']}',
                ),
                const SizedBox(height: 16),
                for (final (index, step) in knowledgeStringList(
                  payload['steps'],
                ).indexed) ...[
                  _section(context, 'Step ${index + 1}', step),
                  const SizedBox(height: 12),
                ],
                if ('${payload['escalationText']}'.trim().isNotEmpty)
                  _section(
                    context,
                    'When to stop and escalate',
                    '${payload['escalationText']}',
                  ),
                const SizedBox(height: 16),
                Text(
                  'Tags: ${knowledgeStringList(payload['tags']).join(', ')}',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _section(BuildContext context, String title, String text) => HDCCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SelectableText(text, style: const TextStyle(height: 1.5)),
      ],
    ),
  );
}
