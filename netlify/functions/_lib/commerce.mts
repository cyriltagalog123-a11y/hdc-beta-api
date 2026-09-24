export const SELLING_ROLE_CODES = ['seller', 'supplier', 'store'] as const;
export type SellingRoleCode = typeof SELLING_ROLE_CODES[number];

export const PRODUCT_LISTING_STATUS_CODES = [
  'draft',
  'active',
  'paused',
  'sold',
  'archived',
] as const;
export type ProductListingStatus =
  typeof PRODUCT_LISTING_STATUS_CODES[number];

export const PRODUCT_CONDITION_CODES = [
  'new',
  'open_box',
  'used',
  'refurbished',
  'for_parts',
] as const;
export type ProductConditionCode = typeof PRODUCT_CONDITION_CODES[number];

export const PRODUCT_CATEGORY_CODES = [
  'computers',
  'laptops',
  'mobile_devices',
  'pos_equipment',
  'networking',
  'parts_components',
  'accessories',
  'software_licenses',
  'other_technology',
] as const;
export type ProductCategoryCode = typeof PRODUCT_CATEGORY_CODES[number];

export const PRODUCT_PURCHASE_STATUS_CODES = [
  'submitted',
  'accepted',
  'fulfilled',
  'completed',
  'declined',
  'cancelled',
] as const;
export type ProductPurchaseStatus =
  typeof PRODUCT_PURCHASE_STATUS_CODES[number];

export const PRODUCT_PURCHASE_ACTION_CODES = [
  'accept',
  'decline',
  'cancel',
] as const;
export type ProductPurchaseAction =
  typeof PRODUCT_PURCHASE_ACTION_CODES[number];

export type ProductPurchaseRequestWrite = Readonly<{
  listingId: string;
  quantity: number;
  buyerNote: string;
  clientRequestId: string;
  fulfillmentMethod: 'pickup' | 'delivery';
  fulfillmentLocation: string;
  fulfillmentTiming: string;
  fulfillmentFeeMinor: number;
}>;

export const COMMERCE_PAGE_SIZE = 100;
export type CommerceCursor = Readonly<{
  at: string; id: string; price?: number; filter?: string;
}>;

export function parseCommerceCursor(value: string | null): CommerceCursor | null {
  if (value === null) return null;
  if (!/^[A-Za-z0-9_-]{1,512}$/.test(value)) throw new Error('invalid_cursor');
  try {
    const item: unknown = JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
    if (typeof item !== 'object' || item === null) throw new Error();
    const cursor = item as Record<string, unknown>;
    if (typeof cursor.at !== 'string' ||
        !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}(?:\d{3})?Z$/.test(cursor.at) ||
        !Number.isFinite(Date.parse(cursor.at)) ||
        new Date(cursor.at).toISOString().slice(0, 23) !== cursor.at.slice(0, 23) ||
        typeof cursor.id !== 'string' || !uuidPattern.test(cursor.id) ||
        (cursor.price !== undefined &&
          (wholeNumber(cursor.price, 1, 999999999999) === null)) ||
        (cursor.filter !== undefined &&
          (typeof cursor.filter !== 'string' || !/^[a-f0-9]{32}$/.test(cursor.filter)))) {
      throw new Error();
    }
    return { at: cursor.at, id: cursor.id.toLowerCase(),
      ...(cursor.price === undefined ? {} : { price: cursor.price as number }),
      ...(cursor.filter === undefined ? {} : { filter: cursor.filter as string }) };
  } catch {
    throw new Error('invalid_cursor');
  }
}

export function commerceNextCursor(
  rows: readonly Record<string, unknown>[],
  column: 'published_at' | 'created_at' | 'submitted_at',
  catalogFilter?: string,
): string | null {
  if (rows.length <= COMMERCE_PAGE_SIZE) return null;
  const last = rows[COMMERCE_PAGE_SIZE - 1];
  return Buffer.from(JSON.stringify({
    at: String(last.cursor_at ?? new Date(String(last[column])).toISOString()),
    id: String(last.id),
    ...(catalogFilter === undefined ? {} : {
      price: Number(last.unit_price_minor), filter: catalogFilter,
    }),
  })).toString('base64url');
}

export type ProductCatalogQuery = Readonly<{
  query: string;
  category: string | null;
  condition: string | null;
  currency: string | null;
  minPriceMinor: number | null;
  maxPriceMinor: number | null;
  lowStockOnly: boolean;
  sort: 'newest' | 'priceLow' | 'priceHigh';
}>;

export function parseProductCatalogQuery(params: URLSearchParams): ProductCatalogQuery | null {
  const query = (params.get('q') ?? '').trim().replace(/\s+/g, ' ');
  const category = params.get('category');
  const condition = params.get('condition');
  const currency = params.get('currency');
  const sort = params.get('sort') ?? 'newest';
  const lowStock = params.get('lowStock') ?? 'false';
  const price = (key: string): number | null | undefined => {
    const value = params.get(key);
    if (value === null) return null;
    if (!/^(?:0|[1-9]\d{0,11})$/.test(value)) return undefined;
    const parsed = Number(value);
    return Number.isSafeInteger(parsed) && parsed <= 999999999999 ? parsed : undefined;
  };
  const minPriceMinor = price('minPriceMinor');
  const maxPriceMinor = price('maxPriceMinor');
  if (query.length > 80 || /[\x00-\x1f\x7f]/.test(query) ||
      (category !== null && !categorySet.has(category)) ||
      (condition !== null && !conditionSet.has(condition)) ||
      (currency !== null && !currencyPattern.test(currency)) ||
      (lowStock !== 'true' && lowStock !== 'false') ||
      (sort !== 'newest' && sort !== 'priceLow' && sort !== 'priceHigh') ||
      minPriceMinor === undefined || maxPriceMinor === undefined ||
      ((sort !== 'newest' || minPriceMinor !== null || maxPriceMinor !== null) &&
        currency === null) ||
      (minPriceMinor !== null && maxPriceMinor !== null && minPriceMinor > maxPriceMinor)) {
    return null;
  }
  return { query, category, condition, currency, minPriceMinor,
    maxPriceMinor, lowStockOnly: lowStock === 'true', sort };
}

export type ProductPurchaseDecisionWrite = Readonly<{
  action: ProductPurchaseAction;
  version: number;
  note: string;
}>;

export type ProductCancellationWrite = Readonly<{
  action: 'request' | 'approve' | 'decline';
  version: number;
  note: string;
}>;

export function parseProductCancellationWrite(
  input: Record<string, unknown>,
): ProductCancellationWrite | null {
  const action = input.action;
  const version = wholeNumber(input.version, 1, Number.MAX_SAFE_INTEGER);
  const note = optionalText(input.note, action === 'request' ? 500 : 1000);
  if ((action !== 'request' && action !== 'approve' && action !== 'decline') ||
      version === null || note === null ||
      (action === 'request' && note.length < 10)) return null;
  return Object.freeze({ action, version, note });
}

export type ProductListingWrite = Readonly<{
  sellerRole: SellingRoleCode;
  categoryCode: ProductCategoryCode;
  title: string;
  description: string;
  condition: ProductConditionCode;
  currency: string;
  unitPriceMinor: number;
  stockQuantity: number;
  status: ProductListingStatus;
  version: number | null;
}>;

const sellingRoleSet = new Set<string>(SELLING_ROLE_CODES);
const listingStatusSet = new Set<string>(PRODUCT_LISTING_STATUS_CODES);
const conditionSet = new Set<string>(PRODUCT_CONDITION_CODES);
const categorySet = new Set<string>(PRODUCT_CATEGORY_CODES);
const purchaseActionSet = new Set<string>(PRODUCT_PURCHASE_ACTION_CODES);
const currencyPattern = /^[A-Z]{3}$/;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function text(
  value: unknown,
  minimumLength: number,
  maximumLength: number,
): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().replace(/\s+/g, ' ');
  if (
    normalized.length < minimumLength ||
    normalized.length > maximumLength
  ) return null;
  return normalized;
}

function wholeNumber(
  value: unknown,
  minimum: number,
  maximum: number,
): number | null {
  if (typeof value !== 'number' || !Number.isSafeInteger(value)) return null;
  if (value < minimum || value > maximum) return null;
  return value;
}

function optionalText(value: unknown, maximumLength: number): string | null {
  if (value === undefined || value === null) return '';
  if (typeof value !== 'string') return null;
  const normalized = value.trim().replace(/\s+/g, ' ');
  return normalized.length <= maximumLength ? normalized : null;
}

export function isSellingRoleCode(value: unknown): value is SellingRoleCode {
  return typeof value === 'string' && sellingRoleSet.has(value);
}

export function isProductListingStatus(
  value: unknown,
): value is ProductListingStatus {
  return typeof value === 'string' && listingStatusSet.has(value);
}

export function parseProductListingWrite(
  input: Record<string, unknown>,
): ProductListingWrite | null {
  const sellerRole = typeof input.sellerRole === 'string'
    ? input.sellerRole.trim().toLowerCase()
    : '';
  const categoryCode = typeof input.categoryCode === 'string'
    ? input.categoryCode.trim().toLowerCase()
    : '';
  const title = text(input.title, 3, 160);
  const description = text(input.description, 10, 4000);
  const condition = typeof input.condition === 'string'
    ? input.condition.trim().toLowerCase()
    : '';
  const currency = typeof input.currency === 'string'
    ? input.currency.trim().toUpperCase()
    : '';
  const unitPriceMinor = wholeNumber(input.unitPriceMinor, 1, 999999999999);
  const stockQuantity = wholeNumber(input.stockQuantity, 0, 1000000);
  const status = typeof input.status === 'string'
    ? input.status.trim().toLowerCase()
    : '';
  const version = input.version === undefined || input.version === null
    ? null
    : wholeNumber(input.version, 1, Number.MAX_SAFE_INTEGER);

  if (
    (input.version !== undefined && input.version !== null && version === null) ||
    !isSellingRoleCode(sellerRole) ||
    !categorySet.has(categoryCode) ||
    !title ||
    !description ||
    !conditionSet.has(condition) ||
    !currencyPattern.test(currency) ||
    unitPriceMinor === null ||
    stockQuantity === null ||
    !isProductListingStatus(status) ||
    (status === 'active' && stockQuantity === 0) ||
    (status === 'sold' && stockQuantity !== 0)
  ) return null;

  return Object.freeze({
    sellerRole,
    categoryCode: categoryCode as ProductCategoryCode,
    title,
    description,
    condition: condition as ProductConditionCode,
    currency,
    unitPriceMinor,
    stockQuantity,
    status,
    version,
  });
}

const transitions: Record<ProductListingStatus, ReadonlySet<ProductListingStatus>> = {
  draft: new Set(['draft', 'active', 'archived']),
  active: new Set(['active', 'paused', 'sold', 'archived']),
  paused: new Set(['paused', 'active', 'sold', 'archived']),
  sold: new Set(['sold', 'archived']),
  archived: new Set(['archived']),
};

export function canTransitionProductListing(
  from: ProductListingStatus,
  to: ProductListingStatus,
): boolean {
  return transitions[from].has(to);
}

export function parseProductPurchaseRequestWrite(
  input: Record<string, unknown>,
): ProductPurchaseRequestWrite | null {
  const listingId = typeof input.listingId === 'string'
    ? input.listingId.trim().toLowerCase()
    : '';
  const clientRequestId = typeof input.clientRequestId === 'string'
    ? input.clientRequestId.trim().toLowerCase()
    : '';
  const quantity = wholeNumber(input.quantity, 1, 1000);
  const buyerNote = optionalText(input.buyerNote, 1000);
  const fulfillmentMethod = input.fulfillmentMethod;
  const fulfillmentLocation = text(input.fulfillmentLocation, 5, 240);
  const fulfillmentTiming = text(input.fulfillmentTiming, 5, 240);
  const fulfillmentFeeMinor = wholeNumber(input.fulfillmentFeeMinor, 0, 999999999);
  if (
    !uuidPattern.test(listingId) ||
    !uuidPattern.test(clientRequestId) ||
    quantity === null ||
    buyerNote === null ||
    (fulfillmentMethod !== 'pickup' && fulfillmentMethod !== 'delivery') ||
    !fulfillmentLocation || !fulfillmentTiming || fulfillmentFeeMinor === null
  ) return null;
  return Object.freeze({ listingId, quantity, buyerNote, clientRequestId,
    fulfillmentMethod, fulfillmentLocation, fulfillmentTiming, fulfillmentFeeMinor });
}

export function parseProductPurchaseDecisionWrite(
  input: Record<string, unknown>,
): ProductPurchaseDecisionWrite | null {
  const action = typeof input.action === 'string'
    ? input.action.trim().toLowerCase()
    : '';
  const version = wholeNumber(input.version, 1, Number.MAX_SAFE_INTEGER);
  const note = optionalText(input.note, 1000);
  if (!purchaseActionSet.has(action) || version === null || note === null) {
    return null;
  }
  return Object.freeze({
    action: action as ProductPurchaseAction,
    version,
    note,
  });
}

export function publicProductListingView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    publicListingId: String(row.public_listing_id),
    sellerPublicName: String(row.seller_public_name),
    sellerPublicProfileId: row.seller_profile_public === true
      ? String(row.seller_profile_public_id)
      : null,
    sellerRole: String(row.seller_role),
    categoryCode: String(row.category_code),
    title: String(row.title),
    description: String(row.description),
    condition: String(row.item_condition),
    currency: String(row.currency),
    unitPriceMinor: Number(row.unit_price_minor),
    stockQuantity: Number(row.stock_quantity),
    publishedAt: new Date(String(row.published_at)).toISOString(),
    updatedAt: new Date(String(row.updated_at)).toISOString(),
  };
}

export function productPurchaseRequestView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  const timeline = Array.isArray(row.timeline) ? row.timeline : [];
  return {
    id: String(row.id),
    publicPurchaseId: String(row.public_purchase_id),
    listingId: String(row.listing_id),
    publicListingId: String(row.public_listing_id_snapshot),
    listingTitle: String(row.listing_title_snapshot),
    sellerPublicName: String(row.seller_name_snapshot),
    sellerRole: String(row.seller_role),
    buyerDisplayName: String(row.buyer_name_snapshot),
    buyerPublicMemberId: String(row.buyer_public_member_id_snapshot),
    quantity: Number(row.quantity),
    currency: String(row.currency),
    unitPriceMinor: Number(row.unit_price_minor),
    subtotalMinor: Number(row.subtotal_minor),
    fulfillment: row.fulfillment_method === null || row.fulfillment_method === undefined
      ? null
      : {
          method: String(row.fulfillment_method),
          location: String(row.fulfillment_location),
          timing: String(row.fulfillment_timing),
          feeMinor: Number(row.fulfillment_fee_minor),
          totalMinor: Number(row.subtotal_minor) + Number(row.fulfillment_fee_minor),
        },
    buyerNote: String(row.buyer_note ?? ''),
    sellerNote: String(row.seller_note ?? ''),
    cancellationRequestedBy: row.cancellation_requested_by
      ? String(row.cancellation_requested_by) === String(row.buyer_user_id)
        ? 'buyer' : 'seller'
      : null,
    cancellationReason: row.cancellation_reason === null ||
      row.cancellation_reason === undefined ? null : String(row.cancellation_reason),
    cancellationRequestedAt: row.cancellation_requested_at
      ? new Date(String(row.cancellation_requested_at)).toISOString() : null,
    cancellationResponseNote: String(row.cancellation_response_note ?? ''),
    stockReleasedAt: row.stock_released_at
      ? new Date(String(row.stock_released_at)).toISOString() : null,
    status: String(row.status),
    version: Number(row.version),
    submittedAt: new Date(String(row.submitted_at)).toISOString(),
    decidedAt: row.decided_at
      ? new Date(String(row.decided_at)).toISOString()
      : null,
    cancelledAt: row.cancelled_at
      ? new Date(String(row.cancelled_at)).toISOString()
      : null,
    updatedAt: new Date(String(row.updated_at)).toISOString(),
    events: timeline.map((event) => {
      const item = event as Record<string, unknown>;
      return {
        type: String(item.type),
        fromStatus: item.fromStatus === null ? null : String(item.fromStatus),
        toStatus: String(item.toStatus),
        occurredAt: new Date(String(item.occurredAt)).toISOString(),
        note: String(item.note ?? ''),
      };
    }),
  };
}

export function productListingView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    publicListingId: String(row.public_listing_id),
    sellerProfileId: String(row.seller_profile_id),
    sellerUserId: String(row.seller_user_id),
    sellerRole: String(row.seller_role),
    categoryCode: String(row.category_code),
    title: String(row.title),
    description: String(row.description),
    condition: String(row.item_condition),
    currency: String(row.currency),
    unitPriceMinor: Number(row.unit_price_minor),
    stockQuantity: Number(row.stock_quantity),
    status: String(row.status),
    version: Number(row.version),
    publishedAt: row.published_at
      ? new Date(String(row.published_at)).toISOString()
      : null,
    soldAt: row.sold_at
      ? new Date(String(row.sold_at)).toISOString()
      : null,
    archivedAt: row.archived_at
      ? new Date(String(row.archived_at)).toISOString()
      : null,
    createdAt: new Date(String(row.created_at)).toISOString(),
    updatedAt: new Date(String(row.updated_at)).toISOString(),
  };
}
