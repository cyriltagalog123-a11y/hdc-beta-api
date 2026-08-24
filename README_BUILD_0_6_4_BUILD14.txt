HDC 0.6.4+14 - MARKETPLACE ITEMS AND SALES DASHBOARD
====================================================

PURPOSE
- Give approved marketplace sellers a clear dashboard location for technology
  items that are selling, inactive, or sold.
- Preserve account and role-profile isolation instead of reviving the old
  disconnected in-memory product catalog.

IMPLEMENTED
- Public dashboard Marketplace Items & Sales card and app-bar shortcut.
- Selling, Inactive, and Sold tabs with truthful empty states.
- Approved Seller, Supplier, and Store workspace selection.
- Create draft, publish, edit, pause, mark sold, and archive actions.
- Integer minor-unit prices, stock validation, immutable public listing IDs,
  optimistic version conflicts, and listing lifecycle evidence.
- Automatic pause of active listings when their selling role is removed.
- Read-only access to prior listing history after a selling role is removed.
- Client-side fail-closed rejection of any cross-account listing payload.
- Migration 0007 and provider/API account-isolation tests.

IMPORTANT LIMITS
- A seller-marked Sold listing is not proof of payment or fulfillment.
- Public catalog discovery, checkout, payment confirmation, receipts, disputes,
  delivery tracking, and listing images remain future commerce sprints.
- No production migration or backend deployment was performed by this package.

RELEASE CHECKS
1. flutter pub get
2. flutter analyze
3. flutter test
4. npm ci
5. npm run verify
6. Apply migration 0007 on an isolated PostgreSQL branch before deployment.
7. Test two seller accounts to confirm listing isolation and version conflicts.
