import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/marketplace_purchase.dart';
import '../../models/product_listing.dart';
import '../../providers/hdc_sales_center_provider.dart';
import '../roles/role_center_screen.dart';
import 'product_listing_edit_screen.dart';

class SalesCenterScreen extends StatefulWidget {
  const SalesCenterScreen({super.key});

  @override
  State<SalesCenterScreen> createState() => _SalesCenterScreenState();
}

class _SalesCenterScreenState extends State<SalesCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HdcSalesCenterProvider>().refresh();
    });
  }

  Future<void> _openEditor([ProductListing? listing]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProductListingEditScreen(listing: listing),
      ),
    );
    if (changed == true && mounted) {
      await context.read<HdcSalesCenterProvider>().refresh();
    }
  }

  void _openRoleCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RoleCenterScreen()),
    );
  }

  Future<void> _changeStatus(
    ProductListing listing,
    ProductListingStatus status,
  ) async {
    if (context.read<HdcSalesCenterProvider>().isSaving) return;
    if (status == ProductListingStatus.sold) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Mark this listing as sold?'),
          content: const Text(
            'This closes the listing and sets its remaining stock to zero. '
            'It records the seller-reported sold state, but it does not by '
            'itself verify payment or create an HDC receipt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Mark Sold'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (status == ProductListingStatus.archived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Archive this listing?'),
          content: const Text(
            'The item will remain in your listing history, but it cannot be '
            'published or edited again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      await context.read<HdcSalesCenterProvider>().changeStatus(
            listing,
            status,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listing changed to ${status.label}.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _decidePurchaseRequest(
    ProductPurchaseRequest request,
    String action,
  ) async {
    if (context.read<HdcSalesCenterProvider>().isSaving) return;
    final accepting = action == 'accept';
    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          accepting ? 'Accept purchase request?' : 'Decline purchase request?',
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${request.buyerDisplayName} requested ${request.quantity} × ${request.listingTitle} for ${request.subtotalLabel}.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: accepting
                      ? 'Message to buyer (optional)'
                      : 'Reason or message (recommended)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                accepting
                    ? 'Accepting allocates ${request.quantity} item(s) from the listing stock. It does not verify payment, issue a receipt, or mark delivery complete.'
                    : 'Declining closes this request without changing inventory.',
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(noteController.text.trim()),
            child: Text(accepting ? 'Accept Request' : 'Decline Request'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (note == null || !mounted) return;

    try {
      await context.read<HdcSalesCenterProvider>().decidePurchaseRequest(
            request,
            action: action,
            note: note,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepting
                ? 'Purchase request accepted and stock allocated.'
                : 'Purchase request declined.',
          ),
        ),
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
    final provider = context.watch<HdcSalesCenterProvider>();
    final hasServerProfiles = provider.sellingProfiles.isNotEmpty;
    final hasWorkspace = provider.canSell || provider.hasListingHistory;
    final manageableRoles = provider.sellingProfiles
        .map((profile) => profile.role)
        .toSet();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: HDCColors.background,
        appBar: AppBar(
          title: const Text('Items & Sales'),
          actions: [
            IconButton(
              tooltip: 'Refresh listings',
              onPressed: provider.isLoading ? null : provider.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: hasWorkspace
              ? const TabBar(
                  tabs: [
                    Tab(text: 'Selling'),
                    Tab(text: 'Inactive'),
                    Tab(text: 'Sold'),
                    Tab(text: 'Orders'),
                  ],
                )
              : null,
        ),
        floatingActionButton: provider.canSell && hasServerProfiles
            ? FloatingActionButton.extended(
                onPressed: provider.isSaving ? null : _openEditor,
                icon: const Icon(Icons.add),
                label: const Text('List Item'),
              )
            : null,
        body: SafeArea(
          child: provider.isLoading && !hasWorkspace
              ? const Center(child: CircularProgressIndicator())
              : !hasWorkspace
              ? _SellingRoleRequired(onOpenRoleCenter: _openRoleCenter)
              : Column(
                  children: [
                    _SalesSummary(provider: provider),
                    if (!provider.canSell)
                      const _ReadOnlyHistoryBanner(),
                    if (provider.lastError != null)
                      _ErrorBanner(
                        message: '${provider.lastError}',
                        onRetry: provider.refresh,
                      ),
                    if (provider.isLoading && provider.listings.isEmpty)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Expanded(
                        child: TabBarView(
                          children: [
                            _ListingList(
                              listings: provider.listings
                                  .where(
                                    (item) => item.status ==
                                        ProductListingStatus.active,
                                  )
                                  .toList(growable: false),
                              emptyTitle: 'Nothing is selling yet',
                              emptyMessage:
                                  'Publish a technology item and it will appear here.',
                              onEdit: _openEditor,
                              onStatus: _changeStatus,
                              canManage: (item) =>
                                  manageableRoles.contains(item.sellerRole),
                            ),
                            _ListingList(
                              listings: provider.listings
                                  .where(
                                    (item) =>
                                        item.status ==
                                            ProductListingStatus.draft ||
                                        item.status ==
                                            ProductListingStatus.paused ||
                                        item.status ==
                                            ProductListingStatus.archived,
                                  )
                                  .toList(growable: false),
                              emptyTitle: 'No inactive listings',
                              emptyMessage:
                                  'Draft, paused, and archived items appear here.',
                              onEdit: _openEditor,
                              onStatus: _changeStatus,
                              canManage: (item) =>
                                  manageableRoles.contains(item.sellerRole),
                            ),
                            _ListingList(
                              listings: provider.listings
                                  .where(
                                    (item) => item.status ==
                                        ProductListingStatus.sold,
                                  )
                                  .toList(growable: false),
                              emptyTitle: 'No sold items recorded',
                              emptyMessage:
                                  'Listings you mark as sold will be preserved here.',
                              onEdit: _openEditor,
                              onStatus: _changeStatus,
                              canManage: (item) =>
                                  manageableRoles.contains(item.sellerRole),
                            ),
                            _SellerOrderList(
                              requests: provider.purchaseRequests,
                              canManage: (request) => manageableRoles
                                  .contains(request.sellerRole),
                              canAccept: (request) => provider.listings.any(
                                (listing) =>
                                    listing.id == request.listingId &&
                                    listing.status ==
                                        ProductListingStatus.active &&
                                    listing.stockQuantity >= request.quantity,
                              ),
                              isSaving: provider.isSaving || provider.isLoading,
                              onDecision: _decidePurchaseRequest,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SalesSummary extends StatelessWidget {
  final HdcSalesCenterProvider provider;

  const _SalesSummary({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          _Metric(
            label: 'Selling',
            value: provider.activeListingCount,
            icon: Icons.sell_outlined,
            color: HDCColors.success,
          ),
          _Metric(
            label: 'Draft/Paused',
            value: provider.draftListingCount + provider.pausedListingCount,
            icon: Icons.pause_circle_outline,
            color: HDCColors.warning,
          ),
          _Metric(
            label: 'Low Stock',
            value: provider.lowStockListingCount,
            icon: Icons.inventory_2_outlined,
            color: HDCColors.danger,
          ),
          _Metric(
            label: 'Buyer Requests',
            value: provider.pendingPurchaseRequestCount,
            icon: Icons.shopping_cart_checkout_outlined,
            color: HDCColors.warning,
          ),
          _Metric(
            label: 'Sold',
            value: provider.soldListingCount,
            icon: Icons.check_circle_outline,
            color: HDCColors.info,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 142,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HDCColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HDCColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListingList extends StatelessWidget {
  final List<ProductListing> listings;
  final String emptyTitle;
  final String emptyMessage;
  final ValueChanged<ProductListing> onEdit;
  final void Function(ProductListing, ProductListingStatus) onStatus;
  final bool Function(ProductListing) canManage;

  const _ListingList({
    required this.listings,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onEdit,
    required this.onStatus,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return _EmptyState(title: emptyTitle, message: emptyMessage);
    }
    return RefreshIndicator(
      onRefresh: context.read<HdcSalesCenterProvider>().refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: listings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final listing = listings[index];
          return _ListingCard(
            listing: listing,
            canManage: canManage(listing),
            onEdit: () => onEdit(listing),
            onStatus: (status) => onStatus(listing, status),
          );
        },
      ),
    );
  }
}

class _SellerOrderList extends StatelessWidget {
  final List<ProductPurchaseRequest> requests;
  final bool Function(ProductPurchaseRequest) canManage;
  final bool Function(ProductPurchaseRequest) canAccept;
  final bool isSaving;
  final void Function(ProductPurchaseRequest, String) onDecision;

  const _SellerOrderList({
    required this.requests,
    required this.canManage,
    required this.canAccept,
    required this.isSaving,
    required this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _EmptyState(
        title: 'No buyer requests yet',
        message:
            'Purchase requests for your active listings will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: context.read<HdcSalesCenterProvider>().refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final request = requests[index];
          return _SellerOrderCard(
            request: request,
            canManage: canManage(request),
            canAccept: canAccept(request),
            isSaving: isSaving,
            onAccept: () => onDecision(request, 'accept'),
            onDecline: () => onDecision(request, 'decline'),
          );
        },
      ),
    );
  }
}

class _SellerOrderCard extends StatelessWidget {
  final ProductPurchaseRequest request;
  final bool canManage;
  final bool canAccept;
  final bool isSaving;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _SellerOrderCard({
    required this.request,
    required this.canManage,
    required this.canAccept,
    required this.isSaving,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final pending = request.status == ProductPurchaseStatus.submitted;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _orderStatusColor(request.status)
                        .withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.shopping_cart_checkout_outlined,
                    color: _orderStatusColor(request.status),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.listingTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${request.quantity} × ${request.unitPriceLabel} • ${request.subtotalLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                _OrderStatusChip(status: request.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Buyer: ${request.buyerDisplayName} • ${request.buyerPublicMemberId}',
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
              Text('Buyer note: ${request.buyerNote}'),
            ],
            if (request.sellerNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Your response: ${request.sellerNote}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (request.status == ProductPurchaseStatus.accepted) ...[
              const SizedBox(height: 10),
              const Text(
                'Inventory was allocated when accepted. Payment, receipt, and fulfillment remain unverified.',
                style: TextStyle(
                  color: HDCColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 14),
              if (canManage)
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: isSaving || !canAccept ? null : onAccept,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Accept & Allocate Stock'),
                    ),
                    OutlinedButton.icon(
                      onPressed: isSaving ? null : onDecline,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Decline'),
                    ),
                  ],
                ),
              if (canManage && !canAccept) ...[
                const SizedBox(height: 8),
                const Text(
                  'This listing is not active with enough stock. Reactivate or restock it before accepting, or decline the request.',
                  style: TextStyle(
                    color: HDCColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ] else if (!canManage)
                const Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: HDCColors.textSecondary,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'This request is read-only because its selling workspace is inactive.',
                        style: TextStyle(color: HDCColors.textSecondary),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  final ProductPurchaseStatus status;

  const _OrderStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _orderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final ProductListing listing;
  final bool canManage;
  final VoidCallback onEdit;
  final ValueChanged<ProductListingStatus> onStatus;

  const _ListingCard({
    required this.listing,
    required this.canManage,
    required this.onEdit,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final editable = listing.status != ProductListingStatus.sold &&
        listing.status != ProductListingStatus.archived;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _statusColor(listing.status).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.devices_other_outlined,
                color: _statusColor(listing.status),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _StatusChip(status: listing.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${listing.priceLabel} • ${listing.condition.label} • Stock ${listing.stockQuantity}',
                    style: const TextStyle(color: HDCColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${listing.categoryLabel} • ${listing.publicListingId}',
                    style: const TextStyle(
                      color: HDCColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (canManage &&
                listing.status != ProductListingStatus.archived)
              PopupMenuButton<String>(
                tooltip: 'Listing actions',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'activate':
                      onStatus(ProductListingStatus.active);
                      break;
                    case 'pause':
                      onStatus(ProductListingStatus.paused);
                      break;
                    case 'sold':
                      onStatus(ProductListingStatus.sold);
                      break;
                    case 'archive':
                      onStatus(ProductListingStatus.archived);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  if (editable)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (listing.status == ProductListingStatus.draft ||
                      listing.status == ProductListingStatus.paused)
                    const PopupMenuItem(
                      value: 'activate',
                      child: Text('Start Selling'),
                    ),
                  if (listing.status == ProductListingStatus.active)
                    const PopupMenuItem(
                      value: 'pause',
                      child: Text('Pause Listing'),
                    ),
                  if (listing.status == ProductListingStatus.active ||
                      listing.status == ProductListingStatus.paused)
                    const PopupMenuItem(
                      value: 'sold',
                      child: Text('Mark as Sold'),
                    ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('Archive'),
                  ),
                ],
              )
            else
              Tooltip(
                message: canManage
                    ? 'Archived listing'
                    : 'This listing is read-only because its selling role is inactive.',
                child: Icon(
                  canManage ? Icons.archive_outlined : Icons.lock_outline,
                  color: HDCColors.textSecondary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ProductListingStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: HDCColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HDCColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyHistoryBanner extends StatelessWidget {
  const _ReadOnlyHistoryBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HDCColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: HDCColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your listing history remains available, but it is read-only while no approved Seller, Supplier, or Store workspace is active.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SellingRoleRequired extends StatelessWidget {
  final VoidCallback onOpenRoleCenter;

  const _SellingRoleRequired({required this.onOpenRoleCenter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 54,
                    color: HDCColors.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Activate a Selling Workspace',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Creating and managing product listings requires an approved Seller, Supplier, or Store role. Your Customer and Technician workspaces remain separate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HDCColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onOpenRoleCenter,
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Open Role Center'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HDCColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: HDCColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

Color _statusColor(ProductListingStatus status) => switch (status) {
      ProductListingStatus.active => HDCColors.success,
      ProductListingStatus.draft => HDCColors.info,
      ProductListingStatus.paused => HDCColors.warning,
      ProductListingStatus.sold => HDCColors.secondary,
      ProductListingStatus.archived => HDCColors.textSecondary,
    };

Color _orderStatusColor(ProductPurchaseStatus status) => switch (status) {
      ProductPurchaseStatus.submitted => HDCColors.warning,
      ProductPurchaseStatus.accepted => HDCColors.success,
      ProductPurchaseStatus.declined => HDCColors.danger,
      ProductPurchaseStatus.cancelled => HDCColors.textSecondary,
    };
