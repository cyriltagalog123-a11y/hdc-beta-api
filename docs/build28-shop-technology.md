# Build 28 — Shop Technology preparation

Status: prepared for the next build. This document does not enable new shop behavior in Build 27.

## Existing foundation

The repository already has a commerce provider, catalog and product detail screens,
seller listings, buyer/seller dashboards, purchase requests and seller decisions.
The API provides `/api/commerce/catalog`, `/api/commerce/listings`, buyer/seller
dashboards, purchase requests and status transitions. Existing PostgreSQL records
and server authorization remain the foundation; a replacement storefront or a
second inventory store is not needed.

## Proposed delivery order

1. Audit current catalog, seller roles, stock rules, purchase statuses and public
   seller profiles against the live Build 27 schema. Record concrete gaps before
   changing the workflow.
2. Improve catalog discovery with clear category, condition, availability and
   price controls. Preserve filters on return from a product. Show useful empty,
   unavailable and retry states on compact and wide layouts.
3. Improve product detail with accurate specifications, condition, currency,
   available quantity and seller identity. Show warranty or fulfillment claims
   only when recorded by the seller; never infer a platform guarantee.
4. Consolidate seller listing creation, draft/publish visibility, stock updates
   and purchase-request decisions. Prevent stale updates and duplicate actions;
   test simultaneous buyers and stock exhaustion against PostgreSQL.
5. Improve the buyer's request history with agreed item/quantity/price, current
   status, permitted next steps and the recorded event history. Keep buyer and
   seller access isolated from unrelated accounts.
6. Connect existing public role profiles to shop identity where authorized.
   Private member email and account security fields must not enter catalog data.

## Decisions to settle during Build 28 review

- Confirm when inventory is reserved and released using the existing request
  state machine before extending checkout behavior.
- Confirm supported fulfillment methods and the fields sellers must complete.
- Identify an approved image-storage path before adding product-photo uploads;
  the current same-origin security policy stays authoritative.
- Confirm whether a cart or saved items is needed after the basic purchase flow
  is verified. Neither is part of this preparation change.

Payments continue to use the existing recorded payment workflow. Payment
processing, custody of funds, refunds through a gateway, shipping integrations
and generated product claims require their own scoped design and approval.

## Acceptance gates

- An approved seller can manage only their listings and eligible decisions.
- An unrelated account cannot read private purchase details or mutate stock.
- Prices retain currency and exact server representation; displayed totals agree
  with the accepted request and quantity.
- Competing purchases, retries, stale versions, cancellations and sold-out items
  produce one consistent inventory and event history.
- Public catalog responses contain only published, permitted product/profile data.
- Buyer and seller flows pass compact/wide Flutter tests and PostgreSQL integration.
- Release identity, dependency audit, encrypted backup/restore, migration
  rehearsal if needed, preview and production verification complete before release.

Build 28 implementation starts after review of the Build 27 operations/profile
update. No Build 28 migration, branch or shop code is included in that update.
