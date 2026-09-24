# Build 28 Shop Technology — first implementation review

Build 27 stabilization shipped in PR #36. This Build 28 increment reuses its
PostgreSQL commerce authority and adds migration 0025 for immutable buyer
fulfillment proposals. It adds no payment processor.

## Implemented in this increment

- Catalog filters for category, condition, available low stock and a chosen
  currency's price range. Price sort is available only within one currency;
  mixed-currency results sort by publish date. Search and filter state survives
  opening and returning from a product.
- A dedicated product view shows the seller-authored description, condition,
  stock, exact currency/price, public seller name and listing reference. It
  refreshes from the catalog and disables requesting a listing that disappears.
- A seller profile link appears only if that role profile is explicitly public
  and the account/role is active. The public endpoint returns a strict field
  list: public name, headline, description and location. It never returns
  private member, email, phone, security or account IDs.
- Buyer and seller purchase history now includes participant-scoped status
  events in order. Timeline data is fetched only with the account's scoped
  purchase rows; it does not expose actor UUIDs or raw event snapshots.
- Existing seller draft/publish/stock/version and buyer request/decision flows
  remain server-authoritative. The existing stock allocation, duplicate retry,
  account isolation and cancellation tests remain release gates.
- New requests record pickup or delivery, location, time window and fee as
  immutable columns. Seller acceptance records agreement to those terms while
  allocating stock; a change requires decline and a new buyer request. Old
  requests display that no terms were recorded. The fee and total are proposals,
  not proof of payment or shipping.
- Stable, bounded pages replace silent 500-row cutoffs. Buyer/seller histories
  and public listings expose cursors and explicit Load More controls. Catalog
  filters and price sort apply to loaded listings, with that limit shown in UI.

## What the shop does not yet claim

The branch includes a runtime database selection guard across every
Netlify Function: preview and branch URLs require a separate
`HDC_PREVIEW_DATABASE_URL`, while the primary origin retains the production
connection. It is checked locally; production and preview configuration still
require an end-to-end identity check once Netlify usage refreshes.

Existing completion status records seller-reported fulfillment and buyer
confirmation; it does not prove payment or external delivery.

No product-photo upload is enabled. Choose a storage provider with quota,
compression, file validation and permissions before enabling it. Cart/saved
items, gateway payments, shipping integrations and generated warranty claims
remain outside this increment. Release evidence and exact revision belong in
the review PR after CI and preview checks.
