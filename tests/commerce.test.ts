import { describe, expect, it } from 'vitest';
import {
  canTransitionProductListing,
  parseProductListingWrite,
  parseProductPurchaseDecisionWrite,
  parseProductPurchaseRequestWrite,
  productListingView,
  productPurchaseRequestView,
  publicProductListingView,
} from '../netlify/functions/_lib/commerce.mjs';

const validWrite = {
  sellerRole: 'seller',
  categoryCode: 'laptops',
  title: 'Refurbished business laptop',
  description: 'A tested technology item with the condition stated clearly.',
  condition: 'refurbished',
  currency: 'PHP',
  unitPriceMinor: 1850000,
  stockQuantity: 2,
  status: 'active',
};

describe('marketplace listing contract', () => {
  it('normalizes a valid technology listing without floating-point money', () => {
    expect(parseProductListingWrite(validWrite)).toMatchObject({
      sellerRole: 'seller',
      categoryCode: 'laptops',
      currency: 'PHP',
      unitPriceMinor: 1850000,
      status: 'active',
      version: null,
    });
  });

  it('requires approved selling roles and truthful active stock', () => {
    expect(parseProductListingWrite({
      ...validWrite,
      sellerRole: 'customer',
    })).toBeNull();
    expect(parseProductListingWrite({
      ...validWrite,
      stockQuantity: 0,
    })).toBeNull();
    expect(parseProductListingWrite({
      ...validWrite,
      categoryCode: 'non_technology_goods',
    })).toBeNull();
  });

  it('requires a sold listing to have zero remaining stock', () => {
    expect(parseProductListingWrite({
      ...validWrite,
      status: 'sold',
      stockQuantity: 0,
      version: 4,
    })).toMatchObject({ status: 'sold', stockQuantity: 0, version: 4 });
    expect(parseProductListingWrite({
      ...validWrite,
      status: 'sold',
      stockQuantity: 1,
    })).toBeNull();
  });

  it('prevents sold or archived listings from being silently reactivated', () => {
    expect(canTransitionProductListing('active', 'sold')).toBe(true);
    expect(canTransitionProductListing('sold', 'active')).toBe(false);
    expect(canTransitionProductListing('archived', 'active')).toBe(false);
  });

  it('returns only the public seller-dashboard listing contract', () => {
    const view = productListingView({
      id: 'listing-1',
      public_listing_id: 'HDC-LST-ABCDEF123456',
      seller_profile_id: 'profile-1',
      seller_user_id: 'user-1',
      seller_role: 'seller',
      category_code: 'laptops',
      title: 'Laptop',
      description: 'A clearly described technology product.',
      item_condition: 'used',
      currency: 'PHP',
      unit_price_minor: 1250000,
      stock_quantity: 1,
      status: 'active',
      version: 2,
      published_at: '2026-08-24T08:00:00.000Z',
      sold_at: null,
      archived_at: null,
      created_at: '2026-08-24T07:00:00.000Z',
      updated_at: '2026-08-24T08:00:00.000Z',
      provider_secret: 'must-not-leak',
    });
    expect(view.publicListingId).toBe('HDC-LST-ABCDEF123456');
    expect(view.unitPriceMinor).toBe(1250000);
    expect(view).not.toHaveProperty('provider_secret');
  });
});

describe('marketplace purchase-request contract', () => {
  it('accepts only bounded quantities with UUID idempotency', () => {
    expect(parseProductPurchaseRequestWrite({
      listingId: 'f1dd4c8b-e6a5-46ff-ae29-739e2d64b78b',
      quantity: 2,
      buyerNote: '  Please confirm   pickup options. ',
      clientRequestId: '4ffdf7ba-c7b6-43ee-82bb-8db78a1c0f04',
    })).toEqual({
      listingId: 'f1dd4c8b-e6a5-46ff-ae29-739e2d64b78b',
      quantity: 2,
      buyerNote: 'Please confirm pickup options.',
      clientRequestId: '4ffdf7ba-c7b6-43ee-82bb-8db78a1c0f04',
    });
    expect(parseProductPurchaseRequestWrite({
      listingId: 'not-an-id',
      quantity: 2,
      clientRequestId: '4ffdf7ba-c7b6-43ee-82bb-8db78a1c0f04',
    })).toBeNull();
    expect(parseProductPurchaseRequestWrite({
      listingId: 'f1dd4c8b-e6a5-46ff-ae29-739e2d64b78b',
      quantity: 0,
      clientRequestId: '4ffdf7ba-c7b6-43ee-82bb-8db78a1c0f04',
    })).toBeNull();
  });

  it('allows only versioned buyer and seller lifecycle actions', () => {
    expect(parseProductPurchaseDecisionWrite({
      action: 'accept',
      version: 3,
      note: 'Pickup is available.',
    })).toEqual({
      action: 'accept',
      version: 3,
      note: 'Pickup is available.',
    });
    expect(parseProductPurchaseDecisionWrite({
      action: 'paid',
      version: 3,
    })).toBeNull();
    expect(parseProductPurchaseDecisionWrite({
      action: 'cancel',
      version: 0,
    })).toBeNull();
  });

  it('keeps account UUIDs out of public and participant-facing views', () => {
    const row = {
      id: '4ffdf7ba-c7b6-43ee-82bb-8db78a1c0f04',
      public_purchase_id: 'HDC-BUY-ABCDEF123456',
      listing_id: 'f1dd4c8b-e6a5-46ff-ae29-739e2d64b78b',
      public_listing_id_snapshot: 'HDC-LST-ABCDEF123456',
      listing_title_snapshot: 'Refurbished laptop',
      seller_name_snapshot: 'HDC Seller Shop',
      seller_role: 'seller',
      seller_user_id: 'private-seller-account-id',
      buyer_user_id: 'private-buyer-account-id',
      buyer_name_snapshot: 'Buyer One',
      buyer_public_member_id_snapshot: 'HDC-MBR-112233445566',
      quantity: 1,
      currency: 'PHP',
      unit_price_minor: 1850000,
      subtotal_minor: 1850000,
      buyer_note: '',
      seller_note: '',
      status: 'submitted',
      version: 1,
      submitted_at: '2026-08-24T10:00:00.000Z',
      decided_at: null,
      cancelled_at: null,
      updated_at: '2026-08-24T10:00:00.000Z',
    };
    const purchaseView = productPurchaseRequestView(row);
    expect(purchaseView).not.toHaveProperty('sellerUserId');
    expect(purchaseView).not.toHaveProperty('buyerUserId');

    const listingView = publicProductListingView({
      id: row.listing_id,
      public_listing_id: row.public_listing_id_snapshot,
      seller_profile_id: 'private-profile-id',
      seller_user_id: row.seller_user_id,
      seller_public_name: row.seller_name_snapshot,
      seller_role: 'seller',
      category_code: 'laptops',
      title: row.listing_title_snapshot,
      description: 'A tested technology item with clear specifications.',
      item_condition: 'refurbished',
      currency: 'PHP',
      unit_price_minor: 1850000,
      stock_quantity: 2,
      published_at: '2026-08-24T09:00:00.000Z',
      updated_at: '2026-08-24T10:00:00.000Z',
    });
    expect(listingView).not.toHaveProperty('sellerUserId');
    expect(listingView).not.toHaveProperty('sellerProfileId');
  });
});
