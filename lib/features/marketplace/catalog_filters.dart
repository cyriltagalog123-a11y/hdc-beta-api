import '../../models/marketplace_purchase.dart';
import '../../models/product_listing.dart';

enum CatalogSort { newest, priceLow, priceHigh }

List<MarketplaceProduct> filterMarketplaceProducts(
  Iterable<MarketplaceProduct> source, {
  String query = '',
  String? category,
  String? condition,
  String? currency,
  int? minimumPriceMinor,
  int? maximumPriceMinor,
  bool lowStockOnly = false,
  CatalogSort sort = CatalogSort.newest,
}) {
  final search = query.trim().toLowerCase();
  final products = source.where((product) {
    if (category != null && product.categoryCode != category) return false;
    if (condition != null && product.condition.code != condition) return false;
    if (lowStockOnly && product.stockQuantity > 3) return false;
    if (currency != null) {
      if (product.currency != currency) return false;
      if (minimumPriceMinor != null &&
          product.unitPriceMinor < minimumPriceMinor) {
        return false;
      }
      if (maximumPriceMinor != null &&
          product.unitPriceMinor > maximumPriceMinor) {
        return false;
      }
    }
    return search.isEmpty ||
        product.title.toLowerCase().contains(search) ||
        product.description.toLowerCase().contains(search) ||
        product.sellerPublicName.toLowerCase().contains(search) ||
        product.publicListingId.toLowerCase().contains(search);
  }).toList(growable: false);

  products.sort((a, b) {
    // Cross-currency price comparisons have no meaningful order.
    if (currency != null && sort != CatalogSort.newest) {
      final priceOrder = a.unitPriceMinor.compareTo(b.unitPriceMinor);
      if (priceOrder != 0) {
        return sort == CatalogSort.priceLow ? priceOrder : -priceOrder;
      }
    }
    final timeOrder = b.publishedAt.compareTo(a.publishedAt);
    return timeOrder != 0 ? timeOrder : a.publicListingId.compareTo(b.publicListingId);
  });
  return products;
}

int? catalogPriceMinor(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}
