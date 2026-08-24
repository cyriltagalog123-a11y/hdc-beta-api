import 'package:flutter/material.dart';

import '../../../core/ui/hdc_colors.dart';

class DashboardMarketplaceOverview extends StatelessWidget {
  final bool guestMode;
  final bool canSell;
  final bool hasListingHistory;
  final bool isLoading;
  final bool isCatalogLoading;
  final int availableProductCount;
  final int pendingBuyerPurchaseCount;
  final int activeListingCount;
  final int soldListingCount;
  final int lowStockListingCount;
  final int pendingPurchaseRequestCount;
  final VoidCallback onBrowseProducts;
  final VoidCallback onOpenSalesCenter;
  final VoidCallback onOpenRoleCenter;

  const DashboardMarketplaceOverview({
    required this.guestMode,
    required this.canSell,
    required this.hasListingHistory,
    required this.isLoading,
    required this.isCatalogLoading,
    required this.availableProductCount,
    required this.pendingBuyerPurchaseCount,
    required this.activeListingCount,
    required this.soldListingCount,
    required this.lowStockListingCount,
    required this.pendingPurchaseRequestCount,
    required this.onBrowseProducts,
    required this.onOpenSalesCenter,
    required this.onOpenRoleCenter,
    super.key,
  });

  String get _subtitle {
    if (isCatalogLoading && availableProductCount == 0) {
      return 'Loading active technology listings.';
    }
    return '$availableProductCount active product listing${availableProductCount == 1 ? '' : 's'} available to browse.';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: HDCColors.secondary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: HDCColors.secondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Technology Marketplace',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle,
                        style: const TextStyle(
                          color: HDCColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onBrowseProducts,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Browse Products'),
              ),
            ),
            if (pendingBuyerPurchaseCount > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 18,
                    color: HDCColors.warning,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '$pendingBuyerPurchaseCount purchase request${pendingBuyerPurchaseCount == 1 ? '' : 's'} awaiting seller decisions.',
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 18),
            Text(
              'Your selling workspace',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            if (guestMode)
              const Text(
                'Sign in to request purchases or manage marketplace listings.',
                style: TextStyle(color: HDCColors.textSecondary),
              )
            else if (isLoading && !canSell && !hasListingHistory)
              const LinearProgressIndicator()
            else if (canSell || hasListingHistory) ...[
              if (isLoading &&
                  activeListingCount == 0 &&
                  soldListingCount == 0)
                const LinearProgressIndicator()
              else
                Row(
                  children: [
                    Expanded(
                      child: _MarketplaceMetric(
                        value: activeListingCount,
                        label: 'Selling',
                        color: HDCColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MarketplaceMetric(
                        value: pendingPurchaseRequestCount,
                        label: 'Buyer Requests',
                        color: HDCColors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MarketplaceMetric(
                        value: soldListingCount,
                        label: 'Sold',
                        color: HDCColors.info,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              if (lowStockListingCount > 0) ...[
                Text(
                  '$lowStockListingCount active listing${lowStockListingCount == 1 ? '' : 's'} running low on stock.',
                  style: const TextStyle(
                    color: HDCColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!canSell) ...[
                const Text(
                  'Your existing records are read-only because no approved selling workspace is active.',
                  style: TextStyle(
                    color: HDCColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenSalesCenter,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(
                    canSell ? 'Open Items & Sales' : 'View Items & Sales',
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'Apply for a Seller, Supplier, or Store workspace before listing products. Internal authority does not automatically grant selling privileges.',
                style: TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onOpenRoleCenter,
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Open Role Center'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketplaceMetric extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _MarketplaceMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
