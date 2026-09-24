import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_gateway.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/core/ui/hdc_theme.dart';
import 'package:hdc_app/features/marketplace/marketplace_catalog_screen.dart';
import 'package:hdc_app/features/marketplace/product_listing_edit_screen.dart';
import 'package:hdc_app/features/marketplace/sales_center_screen.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/models/marketplace_purchase.dart';
import 'package:hdc_app/models/product_listing.dart';
import 'package:hdc_app/providers/hdc_auth_provider.dart';
import 'package:hdc_app/providers/hdc_marketplace_provider.dart';
import 'package:hdc_app/providers/hdc_sales_center_provider.dart';

const _userId = '018f47a2-9b31-7b6c-8b91-4ac78f1c2201';
const _timestamp = '2026-09-16T00:00:00Z';
const _publicName = 'Technology Solutions and Business Equipment Supply Center';

Map<String, dynamic> _listing() => {
  'id': 'listing-one',
  'publicListingId': 'HDC-LST-ABCDEF123456',
  'sellerUserId': _userId,
  'sellerProfileId': 'profile-one',
  'sellerRole': 'seller',
  'categoryCode': 'parts_components',
  'title': 'Refurbished business laptop',
  'description': 'A tested technology item with clear specifications.',
  'condition': 'refurbished',
  'currency': 'USD',
  'unitPriceMinor': 19999,
  'stockQuantity': 2,
  'status': 'active',
  'version': 1,
  'publishedAt': _timestamp,
  'createdAt': _timestamp,
  'updatedAt': _timestamp,
};

Map<String, dynamic> _purchase() => {
  'id': 'purchase-one',
  'publicPurchaseId': 'HDC-BUY-ABCDEF123456',
  'listingId': 'listing-one',
  'publicListingId': 'HDC-LST-ABCDEF123456',
  'listingTitle': 'Refurbished business laptop',
  'sellerPublicName': _publicName,
  'sellerRole': 'seller',
  'buyerDisplayName': 'A Buyer With A Long Display Name',
  'buyerPublicMemberId': 'HDC-MBR-112233445566',
  'quantity': 1,
  'currency': 'USD',
  'unitPriceMinor': 19999,
  'subtotalMinor': 19999,
  'buyerNote': '',
  'sellerNote': '',
  'status': 'fulfilled',
  'version': 3,
  'submittedAt': _timestamp,
  'decidedAt': _timestamp,
  'updatedAt': _timestamp,
};

AccountIdentity _identity({bool canSell = true, String id = _userId}) =>
    AccountIdentity(
      id: id,
      email: 'fixture@example.test',
      displayName: 'Fixture Seller',
      status: HDCAccountStatus.active,
      platformRoles: {
        HDCPlatformRole.customer,
        if (canSell) HDCPlatformRole.seller,
      },
      createdAt: DateTime.utc(2026, 9, 16),
      updatedAt: DateTime.utc(2026, 9, 16),
    );

Future<HdcWorkflowApiClient> _client({
  void Function(Map<String, dynamic>)? onSave,
  List<Map<String, dynamic>> catalog = const [],
}) async {
  final store = MemoryAuthSessionStore();
  await store.write(
    StoredAuthSession(
      token: 'fixture-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  );
  return HdcWorkflowApiClient(
    baseUri: Uri.parse('https://example.test'),
    sessionStore: store,
    client: MockClient((request) async {
      if (request.method == 'PUT') {
        onSave?.call(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'listing': {..._listing(), 'version': 2},
          }),
          200,
        );
      }
      if (request.url.path == '/api/commerce/seller-dashboard') {
        return http.Response(
          jsonEncode({
            'sellingProfiles': [
              {
                'profileId': 'profile-one',
                'role': 'seller',
                'publicName': _publicName,
              },
            ],
            'summary': {
              'activeListings': 1,
              'draftListings': 0,
              'pausedListings': 0,
              'soldListings': 0,
              'lowStockListings': 1,
              'pendingPurchaseRequests': 0,
            },
            'listings': [_listing()],
            'purchaseRequests': [_purchase()],
          }),
          200,
        );
      }
      if (request.url.path == '/api/commerce/buyer-dashboard') {
        return http.Response(
          jsonEncode({
            'purchaseRequests': [_purchase()],
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'listings': catalog}), 200);
    }),
  );
}

void _size(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets(
      'listing editor preserves currency and stops after a role change at $width',
      (tester) async {
        _size(tester, width);
        Map<String, dynamic>? saved;
        final sales = HdcSalesCenterProvider(
          client: await _client(onSave: (body) => saved = body),
        );
        addTearDown(sales.dispose);
        sales.bindIdentity(_identity());
        await tester.runAsync(() => pumpEventQueue(times: 20));
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: sales,
            child: MaterialApp(
              navigatorKey: navigator,
              theme: HDCTheme.lightTheme,
              home: const Scaffold(body: Text('Items home')),
            ),
          ),
        );
        void openEditor() => navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => ProductListingEditScreen(
              listing: ProductListing.fromJson(_listing()),
            ),
          ),
        );
        openEditor();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Save Changes'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Price (USD)'), findsOneWidget);
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();
        expect(saved?['currency'], 'USD');
        expect(saved?['unitPriceMinor'], 19999);
        expect(saved?['version'], 1);
        expect(find.text('Items home'), findsOneWidget);

        openEditor();
        await tester.pumpAndSettle();
        sales.bindIdentity(_identity(canSell: false));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('no longer available to this account'),
          findsOneWidget,
        );
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Save Changes'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('seller order status and account switch stay safe at $width', (
      tester,
    ) async {
      _size(tester, width);
      final sales = HdcSalesCenterProvider(client: await _client());
      addTearDown(sales.dispose);
      sales.bindIdentity(_identity());
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: sales,
          child: MaterialApp(
            theme: HDCTheme.lightTheme,
            home: const SalesCenterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      expect(find.text(ProductPurchaseStatus.fulfilled.label), findsOneWidget);
      expect(tester.takeException(), isNull);
      sales.bindIdentity(null);
      await tester.pumpAndSettle();
      expect(find.text('Refurbished business laptop'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('buyer fulfillment status wraps safely at $width', (
      tester,
    ) async {
      _size(tester, width);
      final marketplace = HdcMarketplaceProvider(client: await _client());
      final auth = _SignedInAuth();
      addTearDown(marketplace.dispose);
      addTearDown(auth.dispose);
      marketplace.bindIdentity(_identity());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: marketplace),
            ChangeNotifierProvider<HDCAuthProvider>.value(value: auth),
          ],
          child: MaterialApp(
            theme: HDCTheme.lightTheme,
            home: const MarketplaceCatalogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Purchases'));
      await tester.pumpAndSettle();
      expect(find.text(ProductPurchaseStatus.fulfilled.label), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('catalog filters and details retain navigation at $width', (
      tester,
    ) async {
      _size(tester, width);
      final marketplace = HdcMarketplaceProvider(client: await _client(
        catalog: [{..._listing(), 'sellerPublicName': _publicName}],
      ));
      final auth = _SignedInAuth();
      addTearDown(marketplace.dispose);
      addTearDown(auth.dispose);
      marketplace.bindIdentity(_identity());
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: marketplace),
          ChangeNotifierProvider<HDCAuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          theme: HDCTheme.lightTheme,
          home: const MarketplaceCatalogScreen(),
        ),
      ));
      await tester.runAsync(() => pumpEventQueue(times: 20));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('View Details'), 320,
          scrollable: find.descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          ).first);
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();
      expect(find.text('Product details'), findsOneWidget);
      expect(find.textContaining('Description and seller-stated'), findsOneWidget);
      expect(find.textContaining(_publicName), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Technology Marketplace'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _UnusedGateway extends Fake implements AuthGateway {}

class _SignedInAuth extends HDCAuthProvider {
  _SignedInAuth() : super(gateway: _UnusedGateway());
  @override
  bool get authenticated => true;
  @override
  bool get guestMode => false;
}
