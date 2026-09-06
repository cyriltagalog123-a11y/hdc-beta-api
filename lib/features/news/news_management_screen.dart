import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/hdc_workflow_api_client.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_spacing.dart';
import '../../models/hdc_news_post.dart';
import '../../providers/hdc_news_provider.dart';

class NewsManagementScreen extends StatefulWidget {
  const NewsManagementScreen({super.key});

  @override
  State<NewsManagementScreen> createState() => _NewsManagementScreenState();
}

class _NewsManagementScreenState extends State<NewsManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<HdcNewsProvider>().loadAdmin());
    });
  }

  Future<void> _openEditor(HdcNewsPost? post) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _NewsEditorScreen(existing: post),
      ),
    );
    if (saved == true && mounted) {
      await context.read<HdcNewsProvider>().loadAdmin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final news = context.watch<HdcNewsProvider>();
    if (!news.canManage) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only the HDC Owner or an approved Admin can manage public news.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage HDC News'),
        actions: [
          IconButton(
            tooltip: 'Refresh posts',
            onPressed: news.loadingAdmin ? null : news.loadAdmin,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: news.saving ? null : () => _openEditor(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Post'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: news.loadAdmin,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HDCCard(
                        color: HDCColors.primaryDeep,
                        borderColor: HDCColors.accent.withValues(alpha: 0.24),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OWNER / APPROVED ADMIN PUBLISHING',
                              style: TextStyle(
                                color: HDCColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Publish without touching code.',
                              style: TextStyle(
                                color: HDCColors.textLight,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Create feature announcements, general notices, maintenance updates, and supporter recognition from here. Recognition cannot be published unless public naming consent is confirmed.',
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (news.loadingAdmin && news.adminPosts.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (news.adminPosts.isEmpty)
                        HDCCard(
                          child: ListTile(
                            leading: const Icon(Icons.article_outlined),
                            title: const Text('No posts yet'),
                            subtitle: const Text(
                              'Use New Post to publish the first HDC announcement.',
                            ),
                            trailing: FilledButton.icon(
                              onPressed: () => _openEditor(null),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create'),
                            ),
                          ),
                        )
                      else
                        ...news.adminPosts.map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AdminPostCard(
                              post: post,
                              onEdit: () => _openEditor(post),
                            ),
                          ),
                        ),
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

class _AdminPostCard extends StatelessWidget {
  final HdcNewsPost post;
  final VoidCallback onEdit;

  const _AdminPostCard({required this.post, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (post.status) {
      HdcNewsStatus.draft => HDCColors.warning,
      HdcNewsStatus.published => HDCColors.success,
      HdcNewsStatus.archived => HDCColors.textSecondary,
    };
    return HDCCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.article_outlined, color: statusColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text(post.kind.label)),
                    Chip(label: Text(post.status.label)),
                    if (post.isPinned)
                      const Chip(
                        avatar: Icon(Icons.push_pin_outlined, size: 16),
                        label: Text('Pinned'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(post.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                  post.summary,
                  style: const TextStyle(
                    color: HDCColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Edit post',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _NewsEditorScreen extends StatefulWidget {
  final HdcNewsPost? existing;

  const _NewsEditorScreen({this.existing});

  @override
  State<_NewsEditorScreen> createState() => _NewsEditorScreenState();
}

class _NewsEditorScreenState extends State<_NewsEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _body;
  late final TextEditingController _recognitionSubject;
  late HdcNewsKind _kind;
  late HdcNewsStatus _status;
  late bool _pinned;
  late bool _recognitionConsent;

  @override
  void initState() {
    super.initState();
    final post = widget.existing;
    _title = TextEditingController(text: post?.title ?? '');
    _summary = TextEditingController(text: post?.summary ?? '');
    _body = TextEditingController(text: post?.body ?? '');
    _recognitionSubject = TextEditingController(
      text: post?.recognitionSubject ?? '',
    );
    _kind = post?.kind ?? HdcNewsKind.announcement;
    _status = post?.status ?? HdcNewsStatus.draft;
    _pinned = post?.isPinned ?? false;
    _recognitionConsent = post?.recognitionConsentConfirmed ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _body.dispose();
    _recognitionSubject.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kind == HdcNewsKind.recognition &&
        _status == HdcNewsStatus.published &&
        !_recognitionConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confirm the supporter agreed to public recognition before publishing.',
          ),
        ),
      );
      return;
    }

    try {
      await context.read<HdcNewsProvider>().save(
            id: widget.existing?.id,
            kind: _kind,
            title: _title.text,
            summary: _summary.text,
            body: _body.text,
            status: _status,
            isPinned: _pinned,
            recognitionSubject: _kind == HdcNewsKind.recognition
                ? _recognitionSubject.text
                : null,
            recognitionConsentConfirmed:
                _kind == HdcNewsKind.recognition && _recognitionConsent,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on HdcWorkflowException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save post: $error')),
      );
    }
  }

  Future<void> _delete() async {
    final post = widget.existing;
    if (post == null || post.status == HdcNewsStatus.published) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text(
          'This permanently deletes the draft or archived post. Published posts must be archived first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<HdcNewsProvider>().deletePost(post);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete post: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<HdcNewsProvider>().saving;
    final recognition = _kind == HdcNewsKind.recognition;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New HDC Post' : 'Edit HDC Post'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HDCSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<HdcNewsKind>(
                      initialValue: _kind,
                      decoration: const InputDecoration(labelText: 'Post type'),
                      items: HdcNewsKind.values
                          .map(
                            (kind) => DropdownMenuItem(
                              value: kind,
                              child: Text(kind.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) setState(() => _kind = value);
                            },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _title,
                      maxLength: 160,
                      decoration: const InputDecoration(labelText: 'Headline'),
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? 'Enter a headline.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _summary,
                      maxLength: 320,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Short summary',
                        helperText: 'Shown first in the public News feed.',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? 'Enter a short summary.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _body,
                      maxLength: 12000,
                      minLines: 7,
                      maxLines: 18,
                      decoration: const InputDecoration(
                        labelText: 'Post details',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? 'Enter the post details.'
                          : null,
                    ),
                    if (recognition) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _recognitionSubject,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'Supporter / organization display name',
                          helperText:
                              'Use only the name they agreed may be published.',
                        ),
                        validator: (value) {
                          if (_status != HdcNewsStatus.published) return null;
                          return (value?.trim().length ?? 0) < 2
                              ? 'Enter the approved public display name.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _recognitionConsent,
                        onChanged: saving
                            ? null
                            : (value) => setState(
                                  () => _recognitionConsent = value ?? false,
                                ),
                        title: const Text(
                          'Public recognition consent confirmed',
                        ),
                        subtitle: const Text(
                          'Confirm that the supporter or sponsor agreed to have this recognition posted publicly.',
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    DropdownButtonFormField<HdcNewsStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: HdcNewsStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) setState(() => _status = value);
                            },
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _pinned,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => _pinned = value),
                      title: const Text('Pin this post'),
                      subtitle: const Text(
                        'Pinned posts stay above normal chronological posts while published.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (widget.existing != null &&
                            widget.existing!.status != HdcNewsStatus.published)
                          TextButton.icon(
                            onPressed: saving ? null : _delete,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Delete'),
                          ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: saving ? null : _save,
                          icon: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _status == HdcNewsStatus.published
                                ? 'Save & Publish'
                                : 'Save Post',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
