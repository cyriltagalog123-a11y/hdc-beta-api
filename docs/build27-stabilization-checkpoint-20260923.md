# Build 27 stabilization checkpoint — 23 September 2026

## Release relationship

The public GCash and Maya support QR cards shipped in PR #41. Current production
source revision is `0856e0865922ba6462efb3c9f69c68a17215bc1b`, Netlify
deploy `6ab353aa78c67aff48b0dc93`, version `0.6.4-build.27`. Both deployed
JPEGs match the owner's originals byte for byte. This PR #36 retains them and
continues the remaining Build 27 stabilization work. Build 28 stays paused.

PR #36's source before reconciliation is `c81129baf4d619a1910084bc5c94fcd90789cee0`
with tree `38873163eb96cae21c552bdc37a11941016f87d6`. The QR release was
merged into that source without conflicts or changes to application files;
both QR asset blobs match production. The new merge and documentation revision
must receive its own CI and preview deployment before production promotion.

## Completed review and preview evidence

- PR #36's earlier source CI run 35797913329 passed all jobs: 187 server/static
  tests, 27 isolated PostgreSQL integration tests, 123 Flutter tests, clean
  Flutter analysis and a release web build. The 25 immutable migrations,
  clean rebuild, Build 26-to-27 upgrade rehearsal, dependency audit and
  isolated encrypted restore passed. No new migration or dependency is added.
- Existing preview deploy `6ab3100d203c2c00082cc779` was ready at exactly
  `c81129baf4d619a1910084bc5c94fcd90789cee0`. A read-only smoke check on
  23 September verified root/release/API health and readiness, seven `ok`
  backend checks, public catalog/news/knowledge/technician endpoints, correct
  protected-route 401 responses, security headers and cache policies.
- Browser inspection on that preview completed guest entry, marketplace and
  technician discovery. Both loaded without application errors. At the time
  of inspection there were zero published products and zero public technicians;
  their empty states and guest access boundary rendered. Authenticated seller,
  buyer and service workflows were exercised in isolated integration and widget
  tests, not by creating production transactions.
- The 22 September read-only database audit found 25 migration entries, no
  invalid indexes, unvalidated constraints, disabled HDC triggers, missing
  approved technician profiles or PUBLIC table grants. Production hosting and
  health were rechecked after QR publication. Existing daily encrypted backup
  and isolated full restore run 35705059860 attempt 3 passed at
  `2026-09-22T23:54:36Z`; artifact 10724968258, SHA-256
  `4463554e6cdb052b79a9b859f83e04b0278ecf45a3ff88c4367258e3fc065ebd`.

## Stability corrections awaiting promotion

- Seller/account authorization for catalog, purchase submission, decision and
  fulfillment; version privacy, idempotency detail checks and serialized
  competing stock allocation.
- Flutter account-switch and stale-response handling for buyer/seller records,
  notifications and service transaction tools, plus unread totals and compact
  selling layouts/currency preservation.
- PostgreSQL advisory-lock serialization of login, recovery verification and
  recovery-answer attempt limits across function instances.

## Promotion gates and limits

The final reconciled commit must pass all three HDC CI jobs and have a ready
Netlify preview at the same revision. Keep a production rollback branch at
`0856e0865922ba6462efb3c9f69c68a17215bc1b` and a successful recent
encrypted backup/full restore. After merge, require main CI before publishing
its exact source revision, then confirm the live release manifest, health,
readiness, public routes, protected boundaries and both QR images.

Preview database separation cannot be independently certified from masked
hosting environment values. The preview browser test was read-only; all
destructive data tests used isolated CI PostgreSQL. Email/SMS delivery,
two-factor authentication, object storage and payment processing are not
active features. Production migration-ledger hashes remain unpopulated;
historical function-request logs and independent long-term backup custody
remain unverified. None of these is represented as a completed capability.
