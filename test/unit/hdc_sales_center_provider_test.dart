import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/models/marketplace_purchase.dart';
import 'package:hdc_app/models/product_listing.dart';
import 'package:hdc_app/providers/hdc_sales_center_provider.dart';

const _userId = '018f47a2-9b31-7b6c-8b91-4ac78f1c2201';
const _timestamp = '2026-08-24T10:00:00.000Z';

Map<String, Object?> _listing({
  String id = 'listing-1',
  String sellerUserId = _userId,
  String status = 'active',
  int stock = 2,
  int version = 1,
}) =>
    {
      'id': id,
      'publicListingId': 'HDC-LST-ABCDEF123456',
      'sellerProfileId': 'profile-seller',
      'sellerUserId': sellerUserId,
      'sellerRole': 'seller',
      'categoryCode': 'laptops',
      'title': 'Refurbished business laptop',
      'description': 'A tested technology item with clear specifications.',
      'condition': 'refurbished',
      'currency': 'PHP',
      'unitPriceMinor': 1850000,
      'stockQuantity': stock,
      'status': status,
      'version': version,
      'publishedAt': _timestamp,
      'soldAt': status == 'sold' ? _timestamp : null,
      'archivedAt': null,
      'createdAt': _timestamp,
      'updatedAt': _timestamp,
    };

Map<String, Object?> _purchase({
  String status = 'submitted',
  int version = 1,
}) =>
    {
      'id': '4ffdf7ba-c7b6-43ee-82bb-8db78a1c0f04',
      'publicPurchaseId': 'HDC-BUY-ABCDEF123456',
      'listingId': 'f1dd4c8b-e6a5-46ff-ae29-739e2d64b78b',
      'publicListingId': 'HDC-LST-ABCDEF123456',
      'listingTitle': 'Refurbished business laptop',
      'sellerPublicName': 'HDC Seller Shop',
      'sellerRole': 'seller',
      'buyerDisplayName': 'Buyer One',
      'buyerPublicMemberId': 'HDC-MBR-112233445566',
      'quantity': 1,
      'currency': 'PHP',
      'unitPriceMinor': 1850000,
      'subtotalMinor': 1850000,
      'buyerNote': 'Please confirm pickup options.',
      'sellerNote': status == 'accepted' ? 'Pickup is available.' : '',
      'status': status,
      'version': version,
      'submittedAt': _timestamp,
      'decidedAt': status == 'accepted' ? _timestamp : null,
      'cancelledAt': null,
      'updatedAt': _timestamp,
    };

AccountIdentity _identity(Set<HDCPlatformRole> roles) {
  final now = DateTime(2026, 8, 24);
  return AccountIdentity(
    id: _userId,
    email: 'seller@example.com',
    displayName: 'HDC Seller',
    status: HDCAccountStatus.active,
    platformRoles: roles,
    createdAt: now,
    updatedAt: now,
  );
}

Future<MemoryAuthSessionStore> _sessionStore() async {
  final store = MemoryAuthSessionStore();
  await store.write(
    StoredAuthSession(
      token: 'commerce-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  );
  return store;
}

void main() {
  test('Sales Center loads only the bound seller account listings', () async {
    final store = await _sessionStore();
    final provider = HdcSalesCenterProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((request) async {
          expect(request.url.path, '/api/commerce/seller-dashboard');
          expect(request.headers['authorization'], 'Bearer commerce-token');
          return http.Response(
            jsonEncode({
              'canSell': true,
              'sellingProfiles': [
                {
                  'profileId': 'profile-seller',
                  'role': 'seller',
                  'publicName': 'HDC Seller Shop',
                },
              ],
              'summary': {
                'activeListings': 8,
                'draftListings': 0,
                'pausedListings': 0,
                'soldListings': 4,
                'lowStockListings': 2,
                'pendingPurchaseRequests': 1,
              },
              'listings': [_listing()],
              'purchaseRequests': [_purchase()],
            }),
            200,
          );
        }),
      ),
    );

    provider.bindIdentity(_identity({
      HDCPlatformRole.customer,
      HDCPlatformRole.seller,
    }));
    await pumpEventQueue(times: 20);

    expect(provider.canSell, isTrue);
    expect(provider.activeListingCount, 8);
    expect(provider.soldListingCount, 4);
    expect(provider.lowStockListingCount, 2);
    expect(provider.pendingPurchaseRequestCount, 1);
    expect(
      provider.purchaseRequests.single.status,
      ProductPurchaseStatus.submitted,
    );
    expect(provider.listings.single.sellerUserId, _userId);
    expect(provider.listings.single.priceLabel, '₱18500.00');

    provider.bindIdentity(null);
    await pumpEventQueue();
    expect(provider.listings, isEmpty);
    expect(provider.canSell, isFalse);
    provider.dispose();
  });

  test('Sales Center sends integer minor-unit prices and updates its cache',
      () async {
    final store = await _sessionStore();
    Map<String, dynamic>? submitted;
    final provider = HdcSalesCenterProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'canSell': true,
                'sellingProfiles': [
                  {
                    'profileId': 'profile-seller',
                    'role': 'seller',
                    'publicName': 'HDC Seller Shop',
                  },
                ],
                'summary': {
                  'activeListings': 0,
                  'draftListings': 0,
                  'pausedListings': 0,
                  'soldListings': 0,
                  'lowStockListings': 0,
                  'pendingPurchaseRequests': 0,
                },
                'listings': <Object?>[],
                'purchaseRequests': <Object?>[],
              }),
              200,
            );
          }
          expect(request.method, 'POST');
          expect(request.url.path, '/api/commerce/listings');
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'listing': _listing()}),
            201,
          );
        }),
      ),
    );
    provider.bindIdentity(_identity({HDCPlatformRole.seller}));
    await pumpEventQueue(times: 20);

    await provider.createListing({
      'sellerRole': 'seller',
      'categoryCode': 'laptops',
      'title': 'Refurbished business laptop',
      'description': 'A tested technology item with clear specifications.',
      'condition': 'refurbished',
      'currency': 'PHP',
      'unitPriceMinor': 1850000,
      'stockQuantity': 2,
      'status': 'active',
    });

    expect(submitted?['unitPriceMinor'], 1850000);
    expect(provider.activeListingCount, 1);
    expect(provider.listings.single.status, ProductListingStatus.active);
    provider.dispose();
  });

  test('seller acceptance sends a versioned decision and updates orders',
      () async {
    final store = await _sessionStore();
    Map<String, dynamic>? submitted;
    var accepted = false;
    final provider = HdcSalesCenterProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            expect(
              request.url.path,
              '/api/commerce/purchase-requests/'
              '4ffdf7ba-c7b6-43ee-82bb-8db78a1c0f04/status',
            );
            submitted = jsonDecode(request.body) as Map<String, dynamic>;
            accepted = true;
            return http.Response(
              jsonEncode({'purchaseRequest': _purchase(
                status: 'accepted',
                version: 2,
              )}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'canSell': true,
              'sellingProfiles': [
                {
                  'profileId': 'profile-seller',
                  'role': 'seller',
                  'publicName': 'HDC Seller Shop',
                },
              ],
              'summary': {
                'activeListings': 1,
                'draftListings': 0,
                'pausedListings': 0,
                'soldListings': 0,
                'lowStockListings': 1,
                'pendingPurchaseRequests': accepted ? 0 : 1,
              },
              'listings': [_listing(stock: accepted ? 1 : 2)],
              'purchaseRequests': [
                _purchase(
                  status: accepted ? 'accepted' : 'submitted',
                  version: accepted ? 2 : 1,
                ),
              ],
            }),
            200,
          );
        }),
      ),
    );
    provider.bindIdentity(_identity({HDCPlatformRole.seller}));
    await pumpEventQueue(times: 20);

    await provider.decidePurchaseRequest(
      provider.purchaseRequests.single,
      action: 'accept',
      note: 'Pickup is available.',
    );
    await pumpEventQueue(times: 20);

    expect(submitted, {
      'action': 'accept',
      'version': 1,
      'note': 'Pickup is available.',
    });
    expect(provider.pendingPurchaseRequestCount, 0);
    expect(
      provider.purchaseRequests.single.status,
      ProductPurchaseStatus.accepted,
    );
    provider.dispose();
  });

  test('Sales Center fails closed on a listing from another account',
      () async {
    final store = await _sessionStore();
    final provider = HdcSalesCenterProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'canSell': true,
                'sellingProfiles': [
                  {
                    'profileId': 'profile-seller',
                    'role': 'seller',
                    'publicName': 'HDC Seller Shop',
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
                'listings': [
                  _listing(
                    sellerUserId:
                        '7d67b6b0-97fa-4ac4-9cb3-7f38595576f5',
                  ),
                ],
                'purchaseRequests': <Object?>[],
              }),
              200,
            )),
      ),
    );

    provider.bindIdentity(_identity({HDCPlatformRole.seller}));
    await pumpEventQueue(times: 20);

    expect(provider.listings, isEmpty);
    expect(provider.lastError, isA<HdcWorkflowException>());
    expect(
      (provider.lastError! as HdcWorkflowException).code,
      'invalid_server_response',
    );
    provider.dispose();
  });
}
