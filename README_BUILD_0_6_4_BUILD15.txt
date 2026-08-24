HDC 0.6.4+15 - PRODUCT MARKETPLACE AND FLUTTER WEB AUTHENTICATION
=================================================================

PURPOSE
- Give buyers a clear place to browse products and request a purchase.
- Give approved sellers an account-scoped queue for buyer requests.
- Restore Chrome access to the HDC API without opening it to every website.

IMPLEMENTED
- Dashboard and app-bar Shop Technology entry points.
- Public active-listing catalog with local search and category filters.
- Guest browsing and registered-Customer purchase-request gating.
- My Purchases history with versioned cancellation while still pending.
- Seller Orders tab with accept/decline controls and buyer public references.
- Atomic stock allocation on acceptance and automatic Sold state at zero stock.
- Migration 0008 with participant isolation, UUID idempotency, integer
  minor-unit totals, lifecycle events, self-purchase prevention, and pending-
  request cleanup when a listing or selling role closes.
- Per-account purchase-request rate limiting and one pending request per buyer
  and listing to reduce accidental duplicates and basic request spam.
- Restricted CORS and OPTIONS preflight support for Flutter web. Local loopback
  origins work for Chrome development; each hosted frontend origin must be set
  explicitly in HDC_WEB_ALLOWED_ORIGINS.

IMPORTANT LIMITS
- Request Accepted means inventory was allocated. It is not proof of payment,
  receipt issuance, delivery, fulfillment, or a completed sale.
- Payment, commerce messaging, delivery tracking, disputes, and listing images
  remain later provider-backed work.
- Submitted requests do not reserve stock. If stock becomes insufficient, the
  seller cannot accept that request.
- No production migration, environment change, or deployment was performed by
  this package.

RELEASE CHECKS
1. Extract Build 15 into a clean folder.
2. Run flutter pub get, flutter analyze, and flutter test.
3. Run npm ci and npm run verify.
4. Apply migration 0008 on an isolated PostgreSQL branch after migrations
   0001-0007 and rehearse accept/decline/cancel concurrency.
5. Deploy the matching API with HDC_WEB_ALLOWED_ORIGINS set to each exact
   hosted Flutter web origin.
6. Test Chrome preflight/login, guest catalog browsing, buyer request/cancel,
   seller accept/decline, stock allocation, self-purchase rejection, and two-
   account isolation before any production promotion.
