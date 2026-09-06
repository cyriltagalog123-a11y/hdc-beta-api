import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../providers/hdc_community_provider.dart';

class CommunityCenterScreen extends StatefulWidget {
  const CommunityCenterScreen({super.key});

  @override
  State<CommunityCenterScreen> createState() => _CommunityCenterScreenState();
}

class _CommunityCenterScreenState extends State<CommunityCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HdcCommunityProvider>().refreshAll();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HdcCommunityProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ratings & Badges'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Ratings', icon: Icon(Icons.star_outline_rounded)),
            Tab(text: 'Badges', icon: Icon(Icons.workspace_premium_outlined)),
          ],
        ),
      ),
      body: provider.isLoading &&
              provider.ratingOpportunities.isEmpty &&
              provider.suggestions.isEmpty &&
              provider.badges.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.refreshAll,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _RatingsTab(provider: provider),
                  _BadgesTab(provider: provider),
                ],
              ),
            ),
    );
  }
}

class _RatingsTab extends StatelessWidget {
  final HdcCommunityProvider provider;
  const _RatingsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        HDCFlowHero(
          eyebrow: 'COMPLETED TRANSACTIONS ONLY',
          title: 'Rate real HDC transaction partners.',
          description:
              'Customers and technicians can rate each other after a completed service. Buyers and sellers can rate each other only after the seller records fulfillment and the buyer confirms completion.',
          icon: Icons.star_rate_rounded,
          tags: [
            HDCFlowTag(
              label: provider.receivedCount == 0
                  ? 'No ratings received yet'
                  : '${provider.receivedAverage.toStringAsFixed(2)} / 5 • ${provider.receivedCount} received',
              icon: Icons.insights_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (provider.ratingOpportunities.isEmpty)
          const HDCEmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No finished transaction needs feedback yet',
            description:
                'Rating opportunities appear automatically from HDC-recorded completed transactions. HDC does not create ratings from unverified activity.',
          )
        else
          for (final item in provider.ratingOpportunities) ...[
            _RatingTransactionCard(item: item, provider: provider),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _RatingTransactionCard extends StatelessWidget {
  final HdcRatingOpportunity item;
  final HdcCommunityProvider provider;
  const _RatingTransactionCard({required this.item, required this.provider});

  @override
  Widget build(BuildContext context) {
    final rating = item.rating;
    return HDCSectionCard(
      title: item.title,
      subtitle: '${item.transactionKind == 'service' ? 'Service' : 'Marketplace'} • ${item.counterpartyName}',
      trailing: Chip(label: Text(item.status.toUpperCase())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.canMarkFulfilled)
            FilledButton.icon(
              onPressed: () => _progress(context),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Seller: Mark Fulfilled'),
            ),
          if (item.canConfirmComplete)
            FilledButton.icon(
              onPressed: () => _progress(context),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Buyer: Confirm Transaction Complete'),
            ),
          if (item.canRate) ...[
            FilledButton.icon(
              onPressed: () => _rate(context),
              icon: const Icon(Icons.star_outline_rounded),
              label: Text('Rate ${item.counterpartyName}'),
            ),
          ] else if (rating != null) ...[
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= ((rating['score'] as num?)?.toInt() ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: HDCColors.warning,
                  ),
              ],
            ),
            if ('${rating['review'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${rating['review']}'),
            ],
          ] else if (item.status != 'completed')
            const Text(
              'Rating stays locked until this transaction is fully completed.',
              style: TextStyle(color: HDCColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Future<void> _progress(BuildContext context) async {
    try {
      await provider.progressCommerce(item);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _rate(BuildContext context) async {
    var score = 5;
    final review = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Rate ${item.counterpartyName}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        tooltip: '$i star${i == 1 ? '' : 's'}',
                        onPressed: () => setState(() => score = i),
                        icon: Icon(
                          i <= score ? Icons.star_rounded : Icons.star_border_rounded,
                          color: HDCColors.warning,
                        ),
                      ),
                  ],
                ),
                TextField(
                  controller: review,
                  maxLength: 1000,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Optional review',
                    hintText: 'Share specific, useful feedback about this completed transaction.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit Rating')),
          ],
        ),
      ),
    );
    if (submitted != true) return;
    try {
      await provider.submitRating(
        transactionKind: item.transactionKind,
        transactionId: item.transactionId,
        score: score,
        review: review.text,
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      review.dispose();
    }
  }
}

class _BadgesTab extends StatelessWidget {
  final HdcCommunityProvider provider;
  const _BadgesTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const HDCFlowHero(
          eyebrow: 'EARNED, NOT BOUGHT',
          title: 'HDC Badges',
          description:
              'Badges come from recorded service, marketplace, or community evidence. Financial support, sponsorship, membership purchases, and ratings cannot buy an HDC badge.',
          icon: Icons.workspace_premium_outlined,
        ),
        const SizedBox(height: 18),
        if (provider.badges.isEmpty)
          const HDCEmptyState(
            icon: Icons.verified_outlined,
            title: 'No earned badges yet',
            description: 'Complete recorded HDC transactions or contribute an implemented suggestion to earn objective milestone badges.',
          )
        else
          for (final badge in provider.badges) ...[
            HDCSectionCard(
              title: badge.name,
              subtitle: badge.category.toUpperCase(),
              trailing: Switch(
                value: badge.visible,
                onChanged: (visible) => provider.setBadgeVisibility(badge, visible),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(badge.description),
                  const SizedBox(height: 8),
                  Text(
                    'Evidence count: ${badge.evidenceCount} • ${badge.visible ? 'Visible on your HDC badge record' : 'Hidden by you'}',
                    style: const TextStyle(color: HDCColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
