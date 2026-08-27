# HDC Change Log

## 0.6.4+20 — 2026-08-27

- Refreshes the complete account-authorized workflow on entry to My Service
  Requests, request details, and the Customer proposal inbox so older requests
  and proposals created in another session do not remain hidden in stale state.
- Serializes proposal autosave and submission, reports validation or network
  failures visibly, and makes canonical proposal retries idempotent even when a
  lost response causes the client to regenerate its proposal identifier.
- Replaces device-local transaction chat with authenticated, transaction-
  participant-only backend conversations and messages that remain available
  across account sessions and devices.
- Adds server moderation, read state, a bounded HDC-managed beta quota,
  account-switch-safe client caches, manual/polling refresh, row-level security,
  migration 0010, and backend/client contract tests.
- Synchronizes Flutter, dashboard, API health, package, CI artifact, and live
  integration release markers at Build 20.

## 0.6.4+19 — 2026-08-26

- Added a dedicated Technician opportunity endpoint so an active Technician
  receives open requests from other accounts without depending on the broad
  workflow bootstrap cache. The server still enforces role and row-level
  authorization and excludes the Technician's own Customer requests.
- Replaced the Find a Technician placeholder with an authenticated live
  directory, manual name/skill/specialty search, service-area prioritization,
  public contact cards, and zero-cost OpenStreetMap area links.
- Preserved profile privacy: only active, approved Technician roles whose
  owners enabled `Publicly discoverable profile` are returned. Account UUIDs
  and internal-role information are never exposed by the directory.
- Added an obvious Browse Technician Jobs action to Technician dashboards,
  account-switch-safe discovery state, and provider tests for both discovery
  routes and area/search behavior.
- Synchronized Flutter, dashboard, API health, package, CI artifact, and live
  integration release markers at Build 19.

## 0.6.4+18 — 2026-08-25

- Refreshes authenticated workflow data whenever a technician opens or pulls
  down the marketplace, with a refresh action, error state, and last-updated
  time so requests posted in another active session appear without relogging.
- Keeps the customer and technician workspaces isolated: My Service Requests
  shows only the signed-in customer's records, the opportunity feed excludes
  that same account's posts, and the API rejects self-proposals.
- Adds searchable technician opportunities, selectable sorting, area-text
  matching from the Technician profile, and a configurable external map search.
  This release does not claim exact distance because coordinates are not yet
  collected with user consent.
- Synchronizes Flutter, dashboard, API health, web package, and release tests at
  Build 18 and adds automated release-marker and generated-web consistency
  gates plus a pinned hosted Flutter analysis/test/build job that synchronizes
  only its verified bundle back to the same first-party review branch.
- Normalizes Flutter's generated service-worker marker to the HDC release ID so
  identical release builds do not create meaningless generated-file changes.

## 0.6.4+17 — 2026-08-24

- Fixed authenticated workflow writes on Neon/PostgreSQL by adding migration
  0009, which grants the database owner explicit permission to enter HDC's
  restricted `hdc_app` RLS role. The earlier membership existed but had its
  `SET ROLE` option disabled.
- Expanded readiness checks so a healthy connection is no longer reported as
  ready when workflow authority is misconfigured.
- Added stable request IDs, duplicate-submit coalescing, and idempotent service-
  request creation so a safe retry cannot publish the same request twice.
- Added safe request reference IDs to API responses and specific client error
  feedback without exposing payloads, credentials, or database details.
- Added an opt-in isolated-database integration test for registration, login,
  request publication, and workflow bootstrap.

## 0.6.4+16 — 2026-08-24

- Structured Netlify as one HTTPS origin for Flutter web, password recovery,
  and the HDC API while keeping database and signing credentials server-only.
- Added a pinned, reproducible Flutter 3.47.1 web build with an enforced
  lockfile, analysis, tests, same-origin API discovery, and reset packaging.
- Added hardened static and JSON response headers, no-store rules for entry and
  recovery pages, and provider-portable deployment/rollback documentation.
- Self-hosted Flutter renderer and font resources on the HDC origin so Chrome
  can load under the restrictive content-security policy without third-party
  CDN access.
- Rehearsed migrations 0006 through 0008 on an isolated Neon branch, then
  promoted the identical transaction to production after approval. Required
  relations, RLS flags, triggers, migration records, and unique account UUIDs
  passed both verification stages; a pre-change rollback branch is retained.
- Updated four transitive packages to the versions pinned by Flutter 3.47.1;
  every hosted archive in the final lockfile was SHA-256 verified before the
  release build.

## 0.6.4+15 — 2026-08-24

- Added a visible Shop Technology action, public active-product catalog,
  product search/category filters, and a signed-in My Purchases workspace.
- Added tracked, quantity-based purchase requests with buyer cancellation and
  Seller/Supplier/Store accept-or-decline controls.
- Made seller acceptance atomically allocate stock and close a listing when
  inventory reaches zero, while explicitly keeping acceptance separate from
  payment, receipt, delivery, and fulfillment evidence.
- Added migration 0008 with participant ownership, UUID idempotency, versioned
  decisions, integer minor-unit totals, lifecycle events, self-purchase
  prevention, and cleanup of pending requests when listings or roles close.
- Added browser CORS and OPTIONS preflight handling with exact configurable
  hosted origins and a narrow loopback exception for local Flutter Chrome.
- Added buyer/seller provider isolation tests, commerce contract tests, and
  browser-origin policy tests.
- No production migration or deployment was performed by this package.

## 0.6.4+14 — 2026-08-24

- Added Marketplace Items & Sales directly to the public dashboard and app bar.
- Added account-scoped Selling, Inactive, and Sold listing workspaces for
  approved Seller, Supplier, and Store profiles.
- Added technology-item draft, publish, edit, pause, seller-marked sold, and
  archive lifecycle controls with integer minor-unit pricing and stock checks.
- Added migration 0007 with immutable HDC listing IDs, role-profile ownership,
  optimistic versioning, lifecycle evidence, and automatic pausing after a
  selling role is removed.
- Preserved prior listing history as read-only when a selling role becomes
  inactive and failed closed if a client receives another account's listing.
- Kept internal roles separate: Owner authority does not automatically grant
  marketplace selling privileges.
- Explicitly kept seller-marked sold state separate from future verified
  checkout, payment, fulfillment, receipt, and dispute records.

## 0.6.4+13 — 2026-08-24

- Added the HDC provider-portability foundation for PostgreSQL hosting, server
  hosting, email/SMS delivery, object storage, and payments.
- Centralized runtime environment access and exported a standard Web API
  handler so Netlify remains a wrapper rather than a domain dependency.
- Added migration 0006 with a schema ledger, recovery-pepper key IDs,
  provider-neutral delivery worker fields, private external-ID mappings, and
  user/organization storage migration checkpoints and data-export manifests.
- Separated recovery peppering from session signing and retained explicit
  legacy/previous keys for controlled migration and rotation.
- Added PostgreSQL readiness checks, encrypted backup/verification tools,
  provider-independent operation modes, cutover/rollback documentation, and
  CI boundary enforcement.
- Kept all paid providers disabled and made no live infrastructure change.

## v0.3 - Keystone

### Added

- Commerce Engine foundation
- Marketplace Profiles
- Product Catalog
- Passport Framework
- Event Bus
- Audit Engine
- Notification Engine
- Global Search
- Nexus Foundation

### Status

Architecture Stabilization Sprint
## v0.6.4+2 - HDC Backend Authentication Cutover

### Added

- HDC-owned HTTPS authentication gateway
- Secure cross-platform session-token storage
- Backend-authoritative role hydration
- Authentication gateway unit tests
- Current-state audit and sprint development records

### Changed

- Removed active Appwrite authentication SDK/provider path
- Aligned registration validation with the HDC backend
- Added Android release network permission and API 23 minimum
- Refreshed safe package versions and HDC beta branding
- Explicit logout now clears the local credential even when remote revocation cannot be confirmed

### Deferred before public beta

- Permanent Android application ID
- Production Android signing
- Password-reset backend flow
- Staged migration of local SharedPreferences repositories to server-backed adapters
- Replacement/clear labeling of demo technician fixture data

## 0.6.4+3 — 2026-08-21
- Clean-package correction to prevent stale provider files surviving ZIP-over-folder extraction.
- Removed dead Supabase auth compatibility source and machine-local Android IDE/config files.
- Added clean extraction instructions; active auth remains HDC API -> Netlify -> Neon.

## 0.6.4+4 — 2026-08-21
- Changed the default HDC auth session policy to process-local: closing and reopening the app now requires sign-in again.
- Kept explicit logout revocation and the provider-neutral auth gateway intact; persistent login is deferred to a future opt-in Remember Me control.
- Locked Guest mode to preview/browse behavior for transactional flows.
- Added reusable registration/sign-in gates for posting requests, bookings, tickets, transactions, role management, HDC Passport, and Technician Marketplace entry.
- Kept technician search/profile browsing available to Guests while blocking booking confirmation until authentication.
- Removed account-style dashboard counts from Guest mode and labeled preview activity as examples only.
- Added a regression test proving a default session is not restored by a new app/gateway instance.
- Added best-effort cleanup/revocation of legacy secure-storage sessions created by the earlier always-persistent policy.

## 0.6.4+5 — 2026-08-21
- Fixed the remaining Flutter analyzer warning in `review_service_request_screen.dart` by removing a redundant non-null assertion after the registered-user identity null guard.
- No behavior change: registered customers still publish service requests with the same authenticated customer ID.
- Repackaged from the user's latest locally tested Build 4 source and removed generated Flutter cache/ephemeral and machine-local IDE/config state before handoff.

## 0.6.4+6 — 2026-08-21
- Added provider-neutral HDC API repositories for service requests, proposals,
  transaction handoffs, and service transactions.
- Made the HTTPS HDC API adapter the default workflow provider while retaining
  an explicit `HDC_BACKEND_PROVIDER=local` development fallback.
- Shared the process-local authenticated session with workflow requests without
  exposing any PostgreSQL credential or provider SDK to Flutter.
- Routed proposal acceptance and transaction transitions through server-owned
  atomic gateways; client repositories consume canonical server responses.
- Cleared workflow caches immediately on account changes and prevented an
  in-flight prior-account refresh from repopulating signed-out data.
- Removed sample marketplace requests from API-backed mode so technicians can
  submit proposals only to real server records.
- Added workflow API transport tests and updated the app widget smoke test.
- Private messages remain local for Sprint 6.4E; final UI redesign remains
  intentionally deferred.

## 0.6.4+7 — 2026-08-21
- Split platform capabilities from private HDC internal authority throughout
  the identity and permission model.
- Platform roles are Customer, Technician, Business, Seller, Supplier, and the
  existing Store workspace; all except Customer require approval.
- Internal roles are Owner, Super Admin, Admin, and community-scoped Moderator;
  internal roles cannot be requested through registration or self-service.
- Replaced the onboarding-preview Role Center destination with a server-backed
  role overview, application status, approval notes, and role notifications.
- Added an Owner/Super Admin approval queue. Admin and Moderator cannot approve
  platform roles or manage the internal hierarchy.
- Added compatibility parsing that safely separates legacy mixed role payloads.
- Added role-domain permission and provider tests.
- Companion backend migration 0003 and endpoints remain staged; production was
  not changed.

## 0.6.4+8 — 2026-08-21

- Added one shared member profile per authenticated HDC account and one
  independently editable profile for every active platform role.
- Added Customer, Technician, Business, Seller, Supplier, and Store profile
  forms under the same login and user ID.
- Added a private internal-staff view composed from internal roles and
  department/section assignments without creating a public staff profile.
- Added profile API routes, strict role-specific validation, migration 0004,
  five profile tests, and dashboard/Role Center access to Profiles & Workspaces.
- Kept production migration and deployment intentionally unchanged.

## 0.6.4+9 — 2026-08-21

- Fixed the two remaining Flutter analyzer findings in the uploaded Build 8
  source: one unused import and one obsolete double-underscore parameter.
- Fixed initial profile selection after an approved role becomes visible during
  the account/profile refresh.
- Re-scanned all project/test Dart references, re-ran backend strict compilation
  and 23 tests, and removed generated machine-local artifacts from packaging.

## 0.6.4+10 — 2026-08-21

- Removed every internal-role, staff-assignment, permission, and approval-queue
  disclosure from the public Role Center, Profile Center, role-overview API, and
  profile-overview API.
- Added a separate private operations dashboard with an authorized switch from
  and back to the public dashboard; ordinary accounts receive no switch, and
  private dashboard data is not prefetched into the public workspace.
- Added permission-filtered operational statistics, private staff assignments,
  sanitized recent activity, and authorized-tool indicators.
- Moved the platform-role approval queue into the private dashboard provider.
- Added `GET /api/internal/dashboard` with server-side internal-access and
  per-statistic permission enforcement; client-side visibility is not trusted
  as authorization.
- Updated the backend contract to 0.5.0, added four backend permission tests,
  and added private-dashboard provider coverage.
- Added `0001_active_neon_auth_contract.sql` after rollout rehearsal exposed the
  active auth bootstrap's constrained-text/platform-enum mismatch. The
  migration validates and preserves existing role rows before conversion and
  deliberately excludes the historical Supabase adapter schema.
- Strict TypeScript compilation and all 27 backend tests pass.
- Rehearsed migrations 0001-0004, profile backfill, RLS, guarded Owner
  bootstrap, audit logging, and private-dashboard statistics on an isolated
  Neon branch before applying the same sequence atomically to production.
- Deployed Backend 0.5.0 to the existing Netlify production site. Live health
  returned 200, while unauthenticated internal, role, and profile routes
  returned 401. The pre-change Neon rollback branch remains retained; no
  GitHub remote was changed.

## 0.6.4+11 — 2026-08-22

- Removed hardcoded dashboard totals and activity records; new accounts now
  start with truthful zero counts and an empty activity state.
- Removed sample technician listings, marketplace requests, customer reviews,
  the ticket simulator, and resettable example ticket numbering.
- Replaced direct-search fixtures with an honest empty live-directory state;
  the connected live workflow is request, proposal, acceptance, transaction.
- Scoped local tickets and saved technician-marketplace items to the complete
  authenticated account UUID and cleared their visible state on account switch.
- Filtered public dashboard requests, offers, transactions, jobs, and activity
  by the signed-in participant UUID for both customer and technician views.
- Added the signed-in email and a shortened display of the UUID to the public
  dashboard header so concurrently tested accounts are easy to distinguish.
- Prevented a delayed prior-account workflow response from replacing the newly
  bound account cache, with a regression test for the race.
- Rejected malformed backend account identifiers in the Flutter auth gateway.
- Verified the live Neon account key is UUID, defaults to `gen_random_uuid()`,
  is the primary key, and all current account IDs are distinct.
- Removed generated Flutter build/cache and IDE metadata from the handoff;
  replaced no-op platform test examples while retaining meaningful test suites.

## 0.6.4+12 — 2026-08-24

- Required three distinct private recovery answers and explicit HDC Beta Terms
  and Privacy acceptance for every new registration.
- Added a non-enumerating Forgot Password flow: two of three correct answers
  create a 15-minute, one-use reset authorization; other results create a
  private manual security review without exposing answers or match counts.
- Added Profiles & Workspaces > Account Security so accounts created before
  Build 12 can set recovery answers after confirming their current password.
- Added Owner/authorized-reviewer recovery queues, one-time manual reset codes,
  rate limits, security audit records, and full session revocation after reset.
- Replaced note-only public-role requests with required, role-specific forms for
  Technician, Business, Seller, Supplier, and Store.
- Added private structured-answer review with Approve, Request Changes, and
  Reject decisions while keeping every internal role out of public app areas.
- Added separate public member IDs while preserving a unique UUID as the sole
  authenticated identity and relationship key for every account.
- Removed obsolete top-level Appwrite setup notes and saved test credentials.
- Applied migration 0005 to the production Neon branch and deployed Backend
  0.6.0 account-recovery and structured-role routes. The final authenticated
  recovery-answer compatibility route remains ready for explicit publication
  approval.
