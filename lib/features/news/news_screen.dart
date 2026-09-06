import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';
import '../../models/hdc_news_post.dart';
import '../../providers/hdc_news_provider.dart';
import 'news_management_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  HdcNewsKind? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<HdcNewsProvider>().loadPublic());
    });
  }

  void _openManagement(BuildContext context) {
    Navigator.of(context).push(
      HDCPageRoute<void>(page: const NewsManagementScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final news = context.watch<HdcNewsProvider>();
    final posts = _filter == null
        ? news.publicPosts
        : news.publicPosts.where((post) => post.kind == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('HDC News'),
        actions: [
          if (news.canManage)
            IconButton(
              tooltip: 'Manage news',
              onPressed: () => _openManagement(context),
              icon: const Icon(Icons.edit_note_rounded),
            ),
          IconButton(
            tooltip: 'Refresh news',
            onPressed: news.loadingPublic ? null : news.loadPublic,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: news.loadPublic,
          child: ListView(
            padding: const EdgeInsets.all(HDCSpacing.lg),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HDCFlowHero(
                        eyebrow: 'PUBLIC NEWSROOM',
                        title: 'What changed in HDC, what is coming, and who helped.',
                        description:
                            'Official HDC feature releases, important announcements, maintenance notices, and supporter recognition are published here by SaiCore. Recognition appears only when the person or organization agreed to be named publicly.',
                        icon: Icons.newspaper_rounded,
                        tags: const [
                          HDCFlowTag(
                            label: 'Public announcements',
                            icon: Icons.campaign_outlined,
                          ),
                          HDCFlowTag(
                            label: 'Recognition by consent',
                            icon: Icons.workspace_premium_outlined,
                          ),
                        ],
                        action: news.canManage
                            ? FilledButton.icon(
                                onPressed: () => _openManagement(context),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Manage Posts'),
                              )
                            : null,
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                      _FilterBar(
                        selected: _filter,
                        onSelected: (value) => setState(() => _filter = value),
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                      if (news.loadingPublic && news.publicPosts.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (posts.isEmpty)
                        HDCEmptyState(
                          icon: Icons.article_outlined,
                          title: _filter == null
                              ? 'No public news has been posted yet'
                              : 'No ${_filter!.label.toLowerCase()} posts yet',
                          description:
                              'When SaiCore publishes a feature release, announcement, maintenance notice, or approved recognition post, it will appear here.',
                        )
                      else
                        ...posts.map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _NewsPostCard(post: post),
                          ),
                        ),
                      if (news.lastError != null && news.publicPosts.isEmpty) ...[
                        const SizedBox(height: 12),
                        HDCCard(
                          borderColor: HDCColors.danger.withValues(alpha: 0.25),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cloud_off_outlined,
                                color: HDCColors.danger,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'HDC News could not refresh. Existing application workflows are unaffected.',
                                ),
                              ),
                              TextButton(
                                onPressed: news.loadPublic,
                                child: const Text('Retry'),
                              ),
                            ],
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
}

class _FilterBar extends StatelessWidget {
  final HdcNewsKind? selected;
  final ValueChanged<HdcNewsKind?> onSelected;

  const _FilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final kind in HdcNewsKind.values)
          ChoiceChip(
            label: Text(kind.label),
            selected: selected == kind,
            onSelected: (_) => onSelected(kind),
          ),
      ],
    );
  }
}

class _NewsPostCard extends StatelessWidget {
  final HdcNewsPost post;

  const _NewsPostCard({required this.post});

  Color get _accent {
    switch (post.kind) {
      case HdcNewsKind.feature:
        return HDCColors.signal;
      case HdcNewsKind.maintenance:
        return HDCColors.warning;
      case HdcNewsKind.recognition:
        return HDCColors.success;
      case HdcNewsKind.announcement:
        return HDCColors.secondary;
    }
  }

  IconData get _icon {
    switch (post.kind) {
      case HdcNewsKind.feature:
        return Icons.auto_awesome_outlined;
      case HdcNewsKind.maintenance:
        return Icons.build_circle_outlined;
      case HdcNewsKind.recognition:
        return Icons.workspace_premium_outlined;
      case HdcNewsKind.announcement:
        return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      borderColor: post.isPinned
          ? _accent.withValues(alpha: 0.34)
          : HDCColors.border,
      elevated: post.isPinned,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon, size: 16, color: _accent),
                    const SizedBox(width: 6),
                    Text(
                      post.kind.label.toUpperCase(),
                      style: TextStyle(
                        color: _accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.isPinned)
                const Chip(
                  avatar: Icon(Icons.push_pin_outlined, size: 16),
                  label: Text('Pinned'),
                ),
              Text(
                _dateLabel(post.publishedAt ?? post.updatedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(post.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            post.summary,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (post.kind == HdcNewsKind.recognition &&
              (post.recognitionSubject?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.favorite_outline_rounded,
                  color: HDCColors.success,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recognizing ${post.recognitionSubject}',
                    style: const TextStyle(
                      color: HDCColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SelectableText(
            post.body,
            style: const TextStyle(height: 1.55),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
