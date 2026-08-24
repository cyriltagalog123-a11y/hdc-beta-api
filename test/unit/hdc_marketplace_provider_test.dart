import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/models/account_identity.dart';
import 'package:hdc_app/models/marketplace_purchase.dart';
import 'package:hdc_app/providers/hdc_marketplace_provider.dart';

const _userId = '018f47a2-9b31-7b6c-8b91-4ac78f1c2201';
const _secondUserId = '12ccfa1e-47ec-4d4e-99dd-d947d5d54d57';
const _listingId = 'f1dd4c8b-e6a5-46ff-ae29-739e2d64b78b';
const _timestamp = '2026-08-24T10:00:00.000Z';

Map<String, Object?> _product() => {
      'id': _listingId,
      'publicListingId': 'HDC-LST-ABCDEF123456',
      'sellerPublicName': 'HDC Seller Shop',
      'sellerRole': 'seller',
      'categoryCode': 'laptops',
      'title': 'Refurbished business laptop',
      'description': 'A tested technology item with clear specifications.',
      'condition': 'refurbished',
      'currency': 'PHP',
      'unitPriceMinor': 1850000,
      'stockQuantity': 2,
      'publishedAt': _timestamp,
      'updatedAt': _timestamp,
    };

Map<String, Object?> _purchase() => {
      'id': '4ffdf7ba-c7b6-43ee-82bb-8db78a1c0f04',
      'publicPurchaseId': 'HDC-BUY-ABCDEF123456',
      'listingId': _listingId,
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
      'sellerNote': '',
      'status': 'submitted',
      'version': 1,
      'submittedAt': _timestamp,
      'decidedAt': null,
      'cancelledAt': null,
      'updatedAt': _timestamp,
    };

AccountIdentity _identity(String id) {
  final timestamp = DateTime(2026, 8, 24);
  return AccountIdentity(
    id: id,
    email: 'buyer@example.com',
    displayName: 'Buyer One',
    status: HDCAccountStatus.active,
    platformRoles: const {HDCPlatformRole.customer},
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

void main() {
  test('guest catalog is public and does not send an authorization header',
      () async {
    final provider = HdcMarketplaceProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: MemoryAuthSessionStore(),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/commerce/catalog');
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(jsonEncode({'listings': [_product()]}), 200);
        }),
      ),
    );

    provider.bindIdentity(null);
    await pumpEventQueue(times: 20);

    expect(provider.availableProductCount, 1);
    expect(provider.products.single.priceLabel, '₱18500.00');
    expect(provider.authenticated, isFalse);
    provider.dispose();
  });

  test('purchase requests are authenticated, idempotent, and account-bound',
      () async {
    final store = MemoryAuthSessionStore();
    await store.write(
      StoredAuthSession(
        token: 'buyer-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    Map<String, dynamic>? submitted;
    final provider = HdcMarketplaceProvider(
      client: HdcWorkflowApiClient(
        baseUri: Uri.parse('https://example.test'),
        sessionStore: store,
        client: MockClient((request) async {
          if (request.url.path == '/api/commerce/catalog') {
            expect(request.headers.containsKey('authorization'), isFalse);
            return http.Response(jsonEncode({'listings': [_product()]}), 200);
          }
          expect(request.headers['authorization'], 'Bearer buyer-token');
          if (request.method == 'GET') {
            expect(request.url.path, '/api/commerce/buyer-dashboard');
            return http.Response(
              jsonEncode({'purchaseRequests': <Object?>[]}),
              200,
            );
          }
          expect(request.method, 'POST');
          expect(request.url.path, '/api/commerce/purchase-requests');
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'purchaseRequest': _purchase()}),
            201,
          );
        }),
      ),
    );

    provider.bindIdentity(_identity(_userId));
    await pumpEventQueue(times: 20);
    await provider.requestPurchase(
      product: provider.products.single,
      quantity: 1,
      buyerNote: 'Please confirm pickup options.',
    );

    expect(submitted?['listingId'], _listingId);
    expect(submitted?['quantity'], 1);
    expect(
      submitted?['clientRequestId'],
      matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      )),
    );
    expect(
      provider.purchaseRequests.single.status,
      ProductPurchaseStatus.submitted,
    );

    provider.bindIdentity(_identity(_secondUserId));
    expect(provider.purchaseRequests, isEmpty);
    provider.dispose();
  });
}
