import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/marketplace_purchase.dart';
import '../../models/product_listing.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/hdc_marketplace_provider.dart';
import '../authentication/registered_user_gate.dart';

const _catalogCategories = <String, String>{
  'computers': 'Desktop computers',
  'laptops': 'Laptops',
  'mobile_devices': 'Mobile devices',
  'pos_equipment': 'POS and business equipment',
  'networking': 'Networking',
  'parts_components': 'Parts and components',
  'accessories': 'Accessories and peripherals',
  'software_licenses': 'Software and licenses',
  'other_technology': 'Other technology',
};

class MarketplaceCatalogScreen extends StatefulWidget {
  const MarketplaceCatalogScreen({super.key});

  @override
  State<MarketplaceCatalogScreen> createState() =>
      _MarketplaceCatalogScreenState();
}

class _MarketplaceCatalogScreenState extends State<MarketplaceCatalogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _query = '';
  String? _category;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<HdcMarketplaceProvider>();
      provider.refreshCatalog();
      if (provider.authenticated) provider.refreshPurchases();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _requestPurchase(MarketplaceProduct product) async {
    if (!await requireRegisteredUser(
      context,
      action: 'request a marketplace purchase',
    )) {
      return;
    }
    if (!mounted) return;

    final maximumQuantity =
        product.stockQuantity > 1000 ? 1000 : product.stockQuantity;
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    final submission = await showDialog<_PurchaseSubmission>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send Purchase Request'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${product.priceLabel} each • ${product.stockQuantity} available • up to $maximumQuantity per request',
                    style: const TextStyle(color: HDCColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final quantity = int.tryParse(value?.trim() ?? '');
                      if (quantity == null ||
                          quantity < 1 ||
                          quantity > maximumQuantity) {
                        return 'Choose 1 to $maximumQuantity item(s).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: noteController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Message to seller (optional)',
                      hintText: 'Ask about pickup, delivery, or item details.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HDCColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: HDCColors.info),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This sends a purchase request only. HDC will not charge you, create a receipt, or claim delivery is complete. Stock is allocated only if the seller accepts.',
                            style: TextStyle(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop(
                _PurchaseSubmission(
                  quantity: int.parse(quantityController.text.trim()),
                  note: noteController.text.trim(),
                ),
              );
            },
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send Request'),
          ),
        ],
      ),
    );
    quantityController.dispose();
    noteController.dispose();
    if (submission == null || !mounted) return;

    try {
      await context.read<HdcMarketplaceProvider>().requestPurchase(
            product: product,
            quantity: submission.quantity,
            buyerNote: submission.note,
          );
      if (!mounted) return;
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase request sent to the seller.'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _cancelPurchase(ProductPurchaseRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel purchase request?'),
        content: Text(
          '${request.publicPurchaseId} will be cancelled. The seller will no longer be able to accept it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Request'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<HdcMarketplaceProvider>().cancelPurchase(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase request cancelled.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HdcMarketplaceProvider>();
    final auth = context.watch<HDCAuthProvider>();
    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Technology Marketplace'),
        actions: [
          IconButton(
            tooltip: 'Refresh marketplace',
            onPressed: provider.isLoadingCatalog
                ? null
                : () {
                    provider.refreshCatalog();
                    if (provider.authenticated) provider.refreshPurchases();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.storefront_outlined), text: 'Shop'),
            Tab(
              icon: Badge(
                isLabelVisible: provider.pendingPurchaseCount > 0,
                label: Text('${provider.pendingPurchaseCount}'),
                child: const Icon(Icons.receipt_long_outlined),
              ),
              text: 'My Purchases',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _CatalogTab(
              provider: provider,
              query: _query,
              category: _category,
              onQueryChanged: (value) => setState(() => _query = value),
              onCategoryChanged: (value) => setState(() => _category = value),
              onPurchase: _requestPurchase,
            ),
            _PurchasesTab(
              provider: provider,
              registered: auth.authenticated && !auth.guestMode,
              onCancel: _cancelPurchase,
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogTab extends StatelessWidget {
  final HdcMarketplaceProvider provider;
  final String query;
  final String? category;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<MarketplaceProduct> onPurchase;

  const _CatalogTab({
    required this.provider,
    required this.query,
    required this.category,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final products = provider.products.where((product) {
      if (category != null && product.categoryCode != category) return false;
      if (normalizedQuery.isEmpty) return true;
      return product.title.toLowerCase().contains(normalizedQuery) ||
          product.description.toLowerCase().contains(normalizedQuery) ||
          product.sellerPublicName.toLowerCase().contains(normalizedQuery) ||
          product.publicListingId.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);

    return RefreshIndicator(
      onRefresh: provider.refreshCatalog,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        children: [
          const _CatalogNotice(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final search = TextField(
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  labelText: 'Search products or sellers',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              );
              final filter = DropdownButtonFormField<String>(
                key: ValueKey(category),
                initialValue: category ?? 'all',
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: 'all',
                    child: Text('All categories'),
                  ),
                  ..._catalogCategories.entries.map(
                    (item) => DropdownMenuItem<String>(
                      value: item.key,
                      child: Text(item.value),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    onCategoryChanged(value == 'all' ? null : value),
              );
              if (!wide) {
                return Column(
                  children: [search, const SizedBox(height: 12), filter],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: search),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: filter),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (provider.catalogError != null)
            _ErrorCard(
              message: '${provider.catalogError}',
              onRetry: provider.refreshCatalog,
            )
          else if (provider.isLoadingCatalog && provider.products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (products.isEmpty)
            const _EmptyCard(
              icon: Icons.search_off_outlined,
              title: 'No products found',
              message: 'Try another search or category. New seller listings will appear here when published.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 3
                    : constraints.maxWidth >= 650
                        ? 2
                        : 1;
                const spacing = 14.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: products
                      .map(
                        (product) => SizedBox(
                          width: width,
                          child: _ProductCard(
                            product: product,
                            onPurchase: () => onPurchase(product),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CatalogNotice extends StatelessWidget {
  const _CatalogNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shopping_bag_outlined, color: HDCColors.secondary),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buy Technology from HDC Sellers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Browse active listings and send a tracked purchase request. Payments and delivery verification will connect later through replaceable service providers.',
                    style: TextStyle(
                      color: HDCColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final MarketplaceProduct product;
  final VoidCallback onPurchase;

  const _ProductCard({required this.product, required this.onPurchase});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: HDCColors.secondary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.devices_other_outlined,
                    color: HDCColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              product.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HDCColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              product.priceLabel,
              style: const TextStyle(
                color: HDCColors.secondary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${product.condition.label} • ${product.stockQuantity} in stock',
              style: const TextStyle(color: HDCColors.textSecondary),
            ),
            const SizedBox(height: 3),
            Text(
              '${product.sellerPublicName} • ${product.sellerRole.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HDCColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${product.categoryLabel} • ${product.publicListingId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HDCColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPurchase,
                icon: const Icon(Icons.shopping_cart_checkout_outlined),
                label: const Text('Request to Buy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchasesTab extends StatelessWidget {
  final HdcMarketplaceProvider provider;
  final bool registered;
  final ValueChanged<ProductPurchaseRequest> onCancel;

  const _PurchasesTab({
    required this.provider,
    required this.registered,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (!registered) {
      return const _EmptyCard(
        icon: Icons.lock_outline,
        title: 'Sign in to track purchases',
        message: 'You can browse products as a guest. A registered HDC account is required to request and track a purchase.',
      );
    }
    if (provider.isLoadingPurchases && provider.purchaseRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.purchaseError != null && provider.purchaseRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _ErrorCard(
            message: '${provider.purchaseError}',
            onRetry: provider.refreshPurchases,
          ),
        ),
      );
    }
    if (provider.purchaseRequests.isEmpty) {
      return const _EmptyCard(
        icon: Icons.receipt_long_outlined,
        title: 'No purchase requests yet',
        message: 'Open the Shop tab and choose Request to Buy on an available product.',
      );
    }
    return RefreshIndicator(
      onRefresh: provider.refreshPurchases,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        itemCount: provider.purchaseRequests.length +
            (provider.purchaseError == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (provider.purchaseError != null && index == 0) {
            return _ErrorCard(
              message: '${provider.purchaseError}',
              onRetry: provider.refreshPurchases,
            );
          }
          final offset = provider.purchaseError == null ? 0 : 1;
          final request = provider.purchaseRequests[index - offset];
          return _PurchaseCard(
            request: request,
            isSaving: provider.isSaving,
            onCancel: () => onCancel(request),
          );
        },
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final ProductPurchaseRequest request;
  final bool isSaving;
  final VoidCallback onCancel;

  const _PurchaseCard({
    required this.request,
    required this.isSaving,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final color = _purchaseStatusColor(request.status);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.listingTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusPill(label: request.status.label, color: color),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              '${request.quantity} × ${request.unitPriceLabel} • Total ${request.subtotalLabel}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              '${request.sellerPublicName} • ${request.sellerRole.label}',
              style: const TextStyle(color: HDCColors.textSecondary),
            ),
            Text(
              '${request.publicPurchaseId} • ${request.publicListingId}',
              style: const TextStyle(
                color: HDCColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (request.buyerNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Your note: ${request.buyerNote}'),
            ],
            if (request.sellerNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Seller response: ${request.sellerNote}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (request.status == ProductPurchaseStatus.accepted) ...[
              const SizedBox(height: 10),
              const Text(
                'Stock has been allocated. This status is not proof of payment, delivery, or an HDC receipt.',
                style: TextStyle(
                  color: HDCColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            if (request.canCancel) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isSaving ? null : onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Request'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: HDCColors.danger.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: HDCColors.danger),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: HDCColors.textSecondary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseSubmission {
  final int quantity;
  final String note;

  const _PurchaseSubmission({required this.quantity, required this.note});
}

Color _purchaseStatusColor(ProductPurchaseStatus status) => switch (status) {
      ProductPurchaseStatus.submitted => HDCColors.warning,
      ProductPurchaseStatus.accepted => HDCColors.success,
      ProductPurchaseStatus.declined => HDCColors.danger,
      ProductPurchaseStatus.cancelled => HDCColors.textSecondary,
    };
