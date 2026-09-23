import 'package:flutter_test/flutter_test.dart';
import 'package:hdc_app/features/marketplace/catalog_filters.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/models/marketplace_purchase.dart';
import 'package:hdc_app/models/product_listing.dart';

MarketplaceProduct product({
  required String id,
  required String currency,
  required int price,
  required int stock,
  required ProductItemCondition condition,
  required int day,
}) => MarketplaceProduct(
  id: id,
  publicListingId: 'HDC-LST-$id',
  sellerPublicName: 'Seller $id',
  sellerRole: HDCPlatformRole.seller,
  categoryCode: 'laptops',
  title: 'Laptop $id',
  description: 'Seller supplied specification for $id',
  condition: condition,
  currency: currency,
  unitPriceMinor: price,
  stockQuantity: stock,
  publishedAt: DateTime.utc(2026, 9, day),
  updatedAt: DateTime.utc(2026, 9, day),
);

void main() {
  final products = [
    product(id: 'A', currency: 'PHP', price: 250000, stock: 2,
        condition: ProductItemCondition.used, day: 1),
    product(id: 'B', currency: 'USD', price: 1000, stock: 10,
        condition: ProductItemCondition.newItem, day: 2),
    product(id: 'C', currency: 'PHP', price: 190000, stock: 8,
        condition: ProductItemCondition.used, day: 3),
  ];

  test('filters condition, stock and price within one currency', () {
    expect(filterMarketplaceProducts(products,
      condition: 'used', currency: 'PHP', minimumPriceMinor: 200000,
      lowStockOnly: true).map((item) => item.id), ['A']);
    expect(filterMarketplaceProducts(products,
      currency: 'PHP', maximumPriceMinor: 200000).map((item) => item.id), ['C']);
  });

  test('never sorts prices across currencies', () {
    expect(filterMarketplaceProducts(products, sort: CatalogSort.priceLow)
        .map((item) => item.id), ['C', 'B', 'A']);
    expect(filterMarketplaceProducts(products, currency: 'PHP',
      sort: CatalogSort.priceLow).map((item) => item.id), ['C', 'A']);
  });

  test('price parsing preserves cents and rejects ambiguous amounts', () {
    expect(catalogPriceMinor('2,500'), isNull);
    expect(catalogPriceMinor('125.50'), 12550);
    expect(catalogPriceMinor('1.999'), isNull);
    expect(catalogPriceMinor(''), isNull);
  });
}
