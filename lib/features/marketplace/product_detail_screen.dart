import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../core/api/hdc_workflow_api_client.dart';
import '../../models/account_identity.dart';
import '../../models/marketplace_purchase.dart';
import '../../models/product_listing.dart';
import '../../providers/hdc_marketplace_provider.dart';
import 'seller_public_profile_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final MarketplaceProduct initialProduct;
  final Future<void> Function(MarketplaceProduct) onPurchase;

  const ProductDetailScreen({
    required this.productId,
    required this.initialProduct,
    required this.onPurchase,
    super.key,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late MarketplaceProduct? _product = widget.initialProduct;
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    final client = context.read<HdcMarketplaceProvider>().client;
    if (client == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final response = await client.getPublic(
        '/api/commerce/catalog/${widget.productId}',
      );
      final listing = MarketplaceProduct.fromJson(
        Map<String, dynamic>.from(response['listing'] as Map),
      );
      if (mounted) setState(() => _product = listing);
    } on HdcWorkflowException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 404) {
        setState(() => _product = null);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Product details'),
        actions: [
          IconButton(
            tooltip: 'Refresh listing',
            onPressed: _isRefreshing ? null : _refresh,
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
                            onPressed: () => widget.onPurchase(product!),
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
