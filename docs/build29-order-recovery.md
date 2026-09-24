# Build 29 — order recovery and catalog-wide discovery

Build 29 stacks on Build 28's Shop Technology branch. It is prepared for review
and a later merge; Netlify usage is exhausted, so neither Build 28 nor Build 29
is released by this branch. Production remains the approved Build 27 revision.

## Accepted-order recovery

- A buyer or seller can request cancellation of an **accepted** purchase with a
  reason. The order and allocated stock remain unchanged while the other
  participant decides. The requester cannot approve their own request.
- The other participant may decline; the order stays accepted and fulfillment
  can continue. The reason and decision are recorded in its scoped timeline.
- Approval changes the order to cancelled and returns its quantity to the
  listing in the same database transaction. A sold-out listing becomes **paused**
  with restored stock; the seller must review and republish it. A paused or
  archived listing remains unpublished. An active listing retains its status.
- Versioned requests, row locks, a one-way stock release marker and database
  constraints reject stale or repeated approval. The existing submitted-order
  cancellation and accepted fulfillment paths keep their separate rules.
- This is an inventory and order-state record. HDC does not transfer payment,
  issue a refund, or verify physical delivery through this action. Those matters
  require separate participant handling.

## Catalog-wide discovery

The public catalog applies bounded text search, category, condition, currency,
price range and low-stock filters in PostgreSQL **before** returning a page.
Newest and single-currency price order use stable cursor pagination. A cursor is
bound to the exact filter set; changing filters starts a fresh page. The
currency chooser covers active listings beyond the first page. Search and price
inputs are validated, and the screen debounces changes.
The product details view refreshes an individual public listing by ID, so a
listing found on a later page remains available when the first page refreshes.

## Review and release sequence

1. Review Build 28 PR #42 and its passed source gates. Build 29's PR targets
   the Build 28 branch so the incremental diff stays focused.
2. Require Build 29 CI: immutable migration manifest, Node typecheck/tests,
   clean schema and legacy upgrade rehearsal, PostgreSQL integration, backup
   restore rehearsal, Flutter analyze/tests/web build, dependency audit.
3. Once Netlify usage refreshes and the owner resumes release work, merge Build
   28 first. Retarget/recheck Build 29 on main and merge only after Build 28's
   preview database identity and release gates have been evaluated.
4. Apply migration 0026 in the normal guarded release process, verify live
   participant order recovery and catalog pagination against a suitable preview
   database, confirm the exact build artifact and production identity, and take
   a fresh backup/restore verification. Do not infer production readiness from
   isolated CI alone.

No gateway payment, automatic refund, shipment tracking, photo storage or
inventory reservation before seller acceptance is introduced here.
