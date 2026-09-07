import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';
import '../../models/service_request_draft.dart';
import '../../providers/hdc_knowledge_provider.dart';
import '../authentication/registered_user_gate.dart';
import '../service_requests/create_service_request_screen.dart';

class KnowledgeArticleScreen extends StatefulWidget {
  final String slug;

  const KnowledgeArticleScreen({required this.slug, super.key});

  @override
  State<KnowledgeArticleScreen> createState() => _KnowledgeArticleScreenState();
}

class _KnowledgeArticleScreenState extends State<KnowledgeArticleScreen> {
  bool _loading = true;
  Object? _error;
  HdcKnowledgeArticle? _article;
  List<HdcKnowledgeArticle> _related = const [];
  bool _feedbackSaving = false;

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
      final result = await context.read<HdcKnowledgeProvider>().loadArticle(
        widget.slug,
      );
      if (!mounted) return;
      setState(() {
        _article = result.$1;
        _related = result.$2;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _feedback(bool helpful) async {
    final article = _article;
    if (article == null || _feedbackSaving) return;
    if (!await requireRegisteredUser(
      context,
      action: 'send Knowledge Base feedback',
    )) {
      return;
    }
    if (!mounted) return;

    var note = '';
    if (!helpful) {
      final controller = TextEditingController();
      final submitted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('What was missing?'),
          content: TextField(
            controller: controller,
            maxLength: 1000,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Optional: tell HDC what should be clearer or added.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send Feedback'),
            ),
          ],
        ),
      );
      note = controller.text.trim();
      controller.dispose();
      if (submitted != true) return;
    }

    setState(() => _feedbackSaving = true);
    try {
      final counts = await context.read<HdcKnowledgeProvider>().submitFeedback(
        article: article,
        helpful: helpful,
        note: note,
      );
      if (!mounted) return;
      setState(() {
        _article = article.withFeedback(
          helpfulCount: counts.$1,
          notHelpfulCount: counts.$2,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Knowledge Base feedback saved.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _feedbackSaving = false);
    }
  }

  Future<void> _requestHelp() async {
    final article = _article;
    if (article == null) return;
    if (!await requireRegisteredUser(
      context,
      action: 'request help after troubleshooting',
    )) {
      return;
    }
    if (!mounted) return;
    final draft = ServiceRequestDraft()
      ..urgency = 'Normal'
      ..problemDescription =
          'I followed HDC Knowledge Base guide ${article.publicArticleId}: '
          '${article.title}. The problem is still unresolved.\n\n'
          'What I observed after the guide: ';
    Navigator.of(context).push(
      HDCPageRoute<void>(page: CreateServiceRequestScreen(initialDraft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Guide')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(error: _error!, onRetry: _load)
            : _buildArticle(context),
      ),
    );
  }

  Widget _buildArticle(BuildContext context) {
    final article = _article;
    if (article == null) {
      return _ErrorState(
        error: 'This HDC guide is unavailable.',
        onRetry: _load,
      );
    }
    final safetyColor = switch (article.safetyLevel) {
      'high' => HDCColors.danger,
      'moderate' => HDCColors.warning,
      _ => HDCColors.success,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HDCSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HDCFlowHero(
                eyebrow: article.publicArticleId,
                title: article.title,
                description: article.summary,
                icon: Icons.menu_book_outlined,
                tags: [
                  HDCFlowTag(
                    label: _categoryLabel(article.category),
                    icon: _categoryIcon(article.category),
                  ),
                  HDCFlowTag(
                    label: '${article.safetyLevel.toUpperCase()} SAFETY',
                    icon: Icons.health_and_safety_outlined,
                  ),
                  HDCFlowTag(
                    label: 'VERSION ${article.version}',
                    icon: Icons.history_outlined,
                  ),
                ],
              ),
              const SizedBox(height: HDCSpacing.lg),
              if (article.safetyNotice.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: safetyColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: safetyColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.health_and_safety_outlined,
                        color: safetyColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Safety boundary',
                              style: TextStyle(
                                color: safetyColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(article.safetyNotice),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: HDCSpacing.lg),
              HDCCard(
                child: Text(article.body, style: const TextStyle(height: 1.6)),
              ),
              const SizedBox(height: HDCSpacing.lg),
              HDCCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guided troubleshooting',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    for (
                      var index = 0;
                      index < article.steps.length;
                      index++
                    ) ...[
                      _StepRow(index: index + 1, text: article.steps[index]),
                      if (index != article.steps.length - 1)
                        const Divider(height: 24),
                    ],
                  ],
                ),
              ),
              if (article.escalationText.trim().isNotEmpty) ...[
                const SizedBox(height: HDCSpacing.lg),
                HDCCard(
                  borderColor: HDCColors.warning.withValues(alpha: 0.32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.stop_circle_outlined,
                            color: HDCColors.warning,
                          ),
                          SizedBox(width: 9),
                          Text(
                            'When to stop and escalate',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(article.escalationText),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: HDCSpacing.lg),
              HDCCard(
                color: HDCColors.surfaceInteractive,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final feedback = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Did this guide help?',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${article.helpfulCount} helpful • '
                          '${article.notHelpfulCount} needs improvement',
                          style: const TextStyle(
                            color: HDCColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _feedbackSaving
                                  ? null
                                  : () => _feedback(true),
                              icon: const Icon(Icons.thumb_up_alt_outlined),
                              label: const Text('Helpful'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _feedbackSaving
                                  ? null
                                  : () => _feedback(false),
                              icon: const Icon(Icons.thumb_down_alt_outlined),
                              label: const Text('Needs improvement'),
                            ),
                          ],
                        ),
                      ],
                    );
                    final help = FilledButton.icon(
                      onPressed: _requestHelp,
                      icon: const Icon(Icons.support_agent_outlined),
                      label: const Text('Still need help? Post a request'),
                    );
                    if (constraints.maxWidth < 620) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [feedback, const SizedBox(height: 16), help],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: feedback),
                        const SizedBox(width: 20),
                        help,
                      ],
                    );
                  },
                ),
              ),
              if (article.tags.isNotEmpty) ...[
                const SizedBox(height: HDCSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in article.tags) Chip(label: Text(tag)),
                  ],
                ),
              ],
              if (_related.isNotEmpty) ...[
                const SizedBox(height: HDCSpacing.xl),
                Text(
                  'Related HDC guides',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                for (final related in _related) ...[
                  _RelatedCard(
                    article: related,
                    onTap: () => Navigator.of(context).pushReplacement(
                      HDCPageRoute<void>(
                        page: ChangeNotifierProvider.value(
                          value: context.read<HdcKnowledgeProvider>(),
                          child: KnowledgeArticleScreen(slug: related.slug),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: HDCSpacing.lg),
              const Text(
                'Nexus may retrieve this guide only from the published HDC Knowledge Base. Build 27 does not authorize Nexus to invent troubleshooting steps that are not supported by published knowledge.',
                style: TextStyle(
                  color: HDCColors.textMuted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String text;

  const _StepRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HDCColors.secondary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: HDCColors.secondary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text, style: const TextStyle(height: 1.5)),
          ),
        ),
      ],
    );
  }
}

class _RelatedCard extends StatelessWidget {
  final HdcKnowledgeArticle article;
  final VoidCallback onTap;

  const _RelatedCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.article_outlined, color: HDCColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  article.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: HDCColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: HDCEmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Knowledge guide unavailable',
          description: '$error',
          actions: [
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _categoryLabel(String category) => switch (category) {
  'pc_laptop' => 'PC & Laptop',
  'phones_mobile' => 'Phones & Mobile',
  'pos_business_tech' => 'POS & Business Tech',
  'network_internet' => 'Network & Internet',
  'printers_peripherals' => 'Printers & Peripherals',
  'security_accounts' => 'Security & Accounts',
  _ => 'Technology',
};

IconData _categoryIcon(String category) => switch (category) {
  'pc_laptop' => Icons.computer_outlined,
  'phones_mobile' => Icons.phone_android_outlined,
  'pos_business_tech' => Icons.point_of_sale_outlined,
  'network_internet' => Icons.router_outlined,
  'printers_peripherals' => Icons.print_outlined,
  'security_accounts' => Icons.security_outlined,
  _ => Icons.build_outlined,
};
