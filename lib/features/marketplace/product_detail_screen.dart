import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/marketplace_purchase.dart';
import '../../models/product_listing.dart';
import '../../providers/hdc_marketplace_provider.dart';
import 'seller_public_profile_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;
  final Future<void> Function(MarketplaceProduct) onPurchase;

  const ProductDetailScreen({
    required this.productId,
    required this.onPurchase,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HdcMarketplaceProvider>();
    MarketplaceProduct? product;
    for (final item in provider.products) {
      if (item.id == productId) {
        product = item;
        break;
      }
    }

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Product details'),
        actions: [
          IconButton(
            tooltip: 'Refresh listing',
            onPressed: provider.isLoadingCatalog ? null : provider.refreshCatalog,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: product == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('This listing is no longer published or available.'),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text(product.categoryLabel)),
                              Chip(label: Text(product.condition.label)),
                              Chip(label: Text('${product.stockQuantity} available')),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(product.title,
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(product.priceLabel,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: HDCColors.secondary,
                                    fontWeight: FontWeight.w800,
                                  )),
                          const SizedBox(height: 12),
                          Text('Listing ${product.publicListingId}'),
                          const Divider(height: 36),
                          Text('Description and seller-stated specifications',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          SelectableText(product.description),
                          const SizedBox(height: 24),
                          Text('Seller', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text('${product.sellerPublicName} • ${product.sellerRole.label}'),
                          if (product.sellerPublicProfileId != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SellerPublicProfileScreen(
                                    profileId: product!.sellerPublicProfileId!,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.person_outline),
                              label: const Text('View public seller profile'),
                            ),
                          ],
                          const SizedBox(height: 20),
                          const Text(
                            'Check the seller description for any stated warranty or fulfillment terms. HDC does not infer a warranty, hold payment, or confirm delivery from a purchase request.',
                            style: TextStyle(color: HDCColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => onPurchase(product!),
                            icon: const Icon(Icons.shopping_cart_checkout_outlined),
                            label: const Text('Request to Buy'),
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
