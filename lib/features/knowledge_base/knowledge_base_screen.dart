import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';
import '../../models/account_identity.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/hdc_community_provider.dart';
import '../../providers/hdc_knowledge_provider.dart';
import 'knowledge_article_screen.dart';
import 'knowledge_management_screen.dart';

class KnowledgeBaseScreen extends StatelessWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = context.read<HdcCommunityProvider>().client;
    return ChangeNotifierProvider(
      create: (_) => HdcKnowledgeProvider(client: client)..search(),
      child: const _KnowledgeBaseBody(),
    );
  }
}

class _KnowledgeBaseBody extends StatefulWidget {
  const _KnowledgeBaseBody();

  @override
  State<_KnowledgeBaseBody> createState() => _KnowledgeBaseBodyState();
}

class _KnowledgeBaseBodyState extends State<_KnowledgeBaseBody> {
  final _searchController = TextEditingController();
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final provider = context.read<HdcKnowledgeProvider>();
      unawaited(
        provider.search(query: value, category: provider.selectedCategory),
      );
    });
  }

  void _selectCategory(String? category) {
    final provider = context.read<HdcKnowledgeProvider>();
    unawaited(
      provider.search(
        query: _searchController.text,
        category: provider.selectedCategory == category ? null : category,
      ),
    );
  }

  void _openArticle(HdcKnowledgeArticle article) {
    Navigator.of(context).push(
      HDCPageRoute<void>(
        page: ChangeNotifierProvider.value(
          value: context.read<HdcKnowledgeProvider>(),
          child: KnowledgeArticleScreen(slug: article.slug),
        ),
      ),
    );
  }

  void _openManagement() {
    Navigator.of(context)
        .push(HDCPageRoute<void>(page: const KnowledgeManagementScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final knowledge = context.watch<HdcKnowledgeProvider>();
    final auth = context.watch<HDCAuthProvider>();
    final roles = auth.identity?.internalRoles ?? const <HDCInternalRole>{};
    final canManage = roles.any(
      (role) =>
          role == HDCInternalRole.owner ||
          role == HDCInternalRole.superAdmin ||
          role == HDCInternalRole.admin,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Base'),
        actions: [
          if (canManage)
            TextButton.icon(
              onPressed: _openManagement,
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Manage Knowledge'),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => knowledge.search(
            query: _searchController.text,
            category: knowledge.selectedCategory,
          ),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(HDCSpacing.lg),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const HDCFlowHero(
                        eyebrow: 'BUILD 27 • LIVE KNOWLEDGE',
                        title: 'HDC Knowledge Base',
                        description: 'Search reviewed HDC troubleshooting guides, follow structured steps, know when to stop, and move directly into a service request when self-service is not enough.',
                        icon: Icons.menu_book_outlined,
                        tags: [
                          HDCFlowTag(
                            label: 'Public troubleshooting',
                            icon: Icons.build_outlined,
                          ),
                          HDCFlowTag(
                            label: 'Versioned articles',
                            icon: Icons.history_outlined,
                          ),
                          HDCFlowTag(
                            label: 'Nexus retrieval authority',
                            icon: Icons.psychology_alt_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                      TextField(
                        controller: _searchController,
                        onChanged: _scheduleSearch,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) => unawaited(
                          knowledge.search(
                            query: value,
                            category: knowledge.selectedCategory,
                          ),
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          labelText: 'Search the HDC Knowledge Base',
                          hintText: 'Example: printer not detected, POS server, Wi-Fi',
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                    unawaited(
                                      knowledge.search(
                                        category: knowledge.selectedCategory,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: HDCSpacing.md),
                      _CategoryGrid(
                        counts: knowledge.categoryCounts,
                        selectedCategory: knowledge.selectedCategory,
                        onSelect: _selectCategory,
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                      _SafetyNotice(),
                      const SizedBox(height: HDCSpacing.lg),
                      _SearchHeader(
                        query: knowledge.query,
                        selectedCategory: knowledge.selectedCategory,
                        count: knowledge.articles.length,
                      ),
                      const SizedBox(height: HDCSpacing.md),
                      if (knowledge.isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (knowledge.errorMessage != null)
                        HDCEmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'Knowledge Base unavailable',
                          description: knowledge.errorMessage!,
                          actions: [
                            OutlinedButton.icon(
                              onPressed: () => knowledge.search(
                                query: _searchController.text,
                                category: knowledge.selectedCategory,
                              ),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        )
                      else if (knowledge.articles.isEmpty)
                        const HDCEmptyState(
                          icon: Icons.search_off_outlined,
                          title: 'No published guide matched',
                          description: 'Try broader technology terms or another category. HDC only returns reviewed, published knowledge here.',
                        )
                      else
                        for (final article in knowledge.articles) ...[
                          _ArticleCard(
                            article: article,
                            onTap: () => _openArticle(article),
                          ),
                          const SizedBox(height: 12),
                        ],
                      const SizedBox(height: HDCSpacing.lg),
                      const HDCCard(
                        color: HDCColors.surfaceInteractive,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.psychology_alt_outlined,
                              color: HDCColors.secondary,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Nexus retrieval in Build 27 is intentionally grounded. It can retrieve only published HDC Knowledge Base versions marked Nexus-ready; this release does not allow Nexus to invent unsupported troubleshooting procedures.',
                                style: TextStyle(
                                  color: HDCColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
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

class _SearchHeader extends StatelessWidget {
  final String query;
  final String? selectedCategory;
  final int count;

  const _SearchHeader({
    required this.query,
    required this.selectedCategory,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = query.isNotEmpty || selectedCategory != null;
    return Row(
      children: [
        Expanded(
          child: Text(
            filtered ? 'Knowledge results' : 'Published HDC guides',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          '$count guide${count == 1 ? '' : 's'}',
          style: const TextStyle(
            color: HDCColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HDCCard(
      borderColor: HDCColors.warning.withValues(alpha: 0.25),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined, color: HDCColors.warning),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'HDC guides are self-service references, not permission to bypass workplace procedures, device safety, warranties, or qualified repair. Each guide shows its safety boundary and when to stop and escalate.',
              style: TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final Map<String, int> counts;
  final String? selectedCategory;
  final ValueChanged<String?> onSelect;

  const _CategoryGrid({
    required this.counts,
    required this.selectedCategory,
    required this.onSelect,
  });

  static const categories = [
    ('pc_laptop', Icons.computer_outlined, 'PC & Laptop'),
    ('phones_mobile', Icons.phone_android_outlined, 'Phones & Mobile'),
    ('pos_business_tech', Icons.point_of_sale_outlined, 'POS & Business Tech'),
    ('network_internet', Icons.router_outlined, 'Network & Internet'),
    ('printers_peripherals', Icons.print_outlined, 'Printers & Peripherals'),
    ('security_accounts', Icons.security_outlined, 'Security & Accounts'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        FilterChip(
          selected: selectedCategory == null,
          avatar: const Icon(Icons.apps_rounded, size: 17),
          label: Text('All (${counts.values.fold<int>(0, (a, b) => a + b)})'),
          onSelected: (_) => onSelect(null),
        ),
        for (final item in categories)
          FilterChip(
            selected: selectedCategory == item.$1,
            avatar: Icon(item.$2, size: 17),
            label: Text('${item.$3} (${counts[item.$1] ?? 0})'),
            onSelected: (_) => onSelect(item.$1),
          ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final HdcKnowledgeArticle article;
  final VoidCallback onTap;

  const _ArticleCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final safetyColor = switch (article.safetyLevel) {
      'high' => HDCColors.danger,
      'moderate' => HDCColors.warning,
      _ => HDCColors.success,
    };
    return HDCCard(
      onTap: onTap,
      elevated: article.isFeatured,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: HDCColors.secondary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _categoryIcon(article.category),
              color: HDCColors.secondary,
            ),
          );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (article.isFeatured) ...[
                    const Icon(
                      Icons.push_pin_outlined,
                      size: 16,
                      color: HDCColors.secondary,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'FEATURED',
                      style: TextStyle(
                        color: HDCColors.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    article.publicArticleId,
                    style: const TextStyle(
                      color: HDCColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                article.title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                article.summary,
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    avatar: Icon(
                      Icons.health_and_safety_outlined,
                      size: 16,
                      color: safetyColor,
                    ),
                    label: Text('${article.safetyLevel.toUpperCase()} SAFETY'),
                  ),
                  Chip(label: Text('v${article.version}')),
                  if (article.helpfulCount + article.notHelpfulCount > 0)
                    Text(
                      '${article.helpfulCount} helpful',
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [icon, const SizedBox(height: 12), content],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(child: content),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(Icons.chevron_right),
              ),
            ],
          );
        },
      ),
    );
  }
}

IconData _categoryIcon(String category) => switch (category) {
  'pc_laptop' => Icons.computer_outlined,
  'phones_mobile' => Icons.phone_android_outlined,
  'pos_business_tech' => Icons.point_of_sale_outlined,
  'network_internet' => Icons.router_outlined,
  'printers_peripherals' => Icons.print_outlined,
  'security_accounts' => Icons.security_outlined,
  _ => Icons.build_outlined,
};
