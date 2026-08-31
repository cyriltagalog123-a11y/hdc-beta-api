# HDC Beta API

Provider-neutral authentication and service-workflow API for HelpDesk Connect
(HDC) beta clients.

## Architecture

HDC Flutter clients call this HTTPS API. The API owns authentication, session
validation, role lookup, workflow authorization, and security auditing. Neon
PostgreSQL is currently the persistence provider and Netlify Functions is
currently the hosting provider. Provider-specific details stay behind the
backend boundary, so Flutter never receives database credentials or direct
database access.

Build 13 adds enforced portability contracts, a standard Web Request/Response
handler, a PostgreSQL migration ledger, external-provider reference isolation,
rotatable security keys, encrypted backup verification, and a cold-standby
runbook. See `docs/PORTABILITY_AND_RECOVERY.md`.

Build 15 adds the buyer side of the technology marketplace. Guests can browse
active listings, registered Customers can send quantity-based purchase
requests, and the owning Seller, Supplier, or Store can accept or decline them.
Acceptance atomically allocates inventory but deliberately does not claim
payment, receipt issuance, delivery, or fulfillment. Build 15 also adds a
restricted browser-origin policy and OPTIONS preflight handling so Flutter web
can reach HDC authentication and workflow routes.

Build 19 gives technician discovery its own API boundary. Approved Technicians
receive open requests posted by other accounts through an explicit opportunity
feed, while Customers can manually search public Technician profiles by name,
skill, specialty, or service area and open a listed area in a map. Technician
profiles remain private until their owner enables public discovery. Exact
radius or kilometer ranking is intentionally deferred until HDC collects
consented coordinates for both request and technician locations.

Build 20 makes the service workflow refresh as one authoritative account-
scoped unit when Customers open requests or proposals. It serializes proposal
autosave and submission, makes canonical retries safe, and replaces local-only
transaction chat with backend-authoritative conversations protected by session
authentication, participant checks, PostgreSQL row-level security, moderation,
read state, and a bounded HDC-managed beta quota.

Build 22 completes the approved post-Build-20 reliability sequence. Build
20.1A adds account notifications and idempotent incremental chat sync; Build
20.1B adds mutual schedule decisions, Technician price change orders, and
service exceptions. Build 21 records externally completed payments, mutual
confirmation, refunds, and immutable receipts without processing funds. Build
22 adds structured-text transaction documents and participant disputes with an
Owner/Super Admin resolution queue. Active disputes freeze mutable service and
payment actions until an authorized resolution is recorded.

Build 24A carries the responsive HDC interface into Customer requests and
Technician discovery. Request creation now has a guided describe-review-publish
flow, My Service Requests adds provider-backed status and offer filters, and the
request record keeps offers and the accepted-service workspace visible without
mobile overflow. Technician search continues to use only approved public
profiles and explicitly labels technician-stated areas, experience,
availability, and rates; it does not invent distance or reputation data.

Build 23 introduces HDC's shared signal-network interface system. It redesigns
the startup, authentication, onboarding, dashboard navigation, dashboard hero,
and primary actions for desktop and mobile while leaving Build 22.1 database,
authorization, transaction, payment, document, dispute, and chat behavior
unchanged.

## Endpoints

- `GET /api/health`
- `GET /api/health/ready` (PostgreSQL readiness; no credentials returned)
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/session`
- `POST /api/auth/logout`
- `POST /api/auth/recovery/start`
- `POST /api/auth/recovery/verify`
- `POST /api/auth/recovery/reset`
- `POST /api/auth/recovery/answers` (authenticated answer setup/replacement)
- `POST /api/auth/password-reset/confirm` (existing-link compatibility)
- `GET /api/roles/overview`
- `POST /api/role-applications`
- `GET /api/internal/dashboard`
- `GET /api/internal/role-applications`
- `PUT /api/internal/role-applications/:id`
- `GET /api/internal/account-recovery`
- `PUT /api/internal/account-recovery/:id`
- `GET /api/internal/disputes`
- `PUT /api/internal/disputes/:id`
- `GET /api/notifications`
- `PUT /api/notifications/read-all`
- `PUT /api/notifications/:id/read`
- `GET /api/profiles`
- `PUT /api/profiles/member`
- `PUT /api/profiles/:role`
- `GET /api/discovery/technicians` (authenticated, public profiles only)
- `GET /api/discovery/opportunities` (active Technician role required)
- `GET /api/commerce/catalog` (public active-listing catalog)
- `GET /api/commerce/buyer-dashboard`
- `GET /api/commerce/seller-dashboard`
- `POST /api/commerce/listings`
- `PUT /api/commerce/listings/:id`
- `POST /api/commerce/purchase-requests`
- `PUT /api/commerce/purchase-requests/:id/status`
- `GET /api/workflow/bootstrap`
- `POST /api/service-requests`
- `PUT /api/service-requests/:id`
- `DELETE /api/service-requests/:id`
- `POST /api/proposals`
- `PUT /api/proposals/:id`
- `DELETE /api/proposals/:id`
- `POST /api/proposals/:id/accept`
- `PUT /api/service-transactions/:id/status`
- `GET /api/service-transactions/:id/toolbox`
- `POST /api/service-transactions/:id/schedule-changes`
- `PUT /api/service-transactions/:id/schedule-changes/:itemId`
- `POST /api/service-transactions/:id/change-orders`
- `PUT /api/service-transactions/:id/change-orders/:itemId`
- `POST /api/service-transactions/:id/exceptions`
- `POST /api/service-transactions/:id/payments`
- `PUT /api/service-transactions/:id/payments/:itemId`
- `POST /api/service-transactions/:id/documents`
- `DELETE /api/service-transactions/:id/documents/:itemId`
- `POST /api/service-transactions/:id/disputes`
- `PUT /api/service-transactions/:id/disputes/:itemId`
- `GET|POST /api/service-transactions/:id/conversation`
- `POST /api/service-transactions/:id/conversation/messages`
- `PUT /api/service-transactions/:id/conversation/read`
- `PUT /api/service-transactions/:id/conversation/storage`

Payment endpoints store participant attestations about payments made through
an external channel. They are not a payment gateway and never accept card,
bank, wallet, or account credentials. Transaction documents are structured
text in Build 22; binary uploads remain disabled until dedicated object storage
and malware scanning are available.

Public registration always creates the `customer` platform role only.
Technician, business, seller, supplier, and store roles require an application
with role-specific required fields reviewed by the authorized HDC review team.
Client-supplied roles are never accepted as authorization.

## Role domains

HDC intentionally keeps two role namespaces:

- Platform roles (`customer`, `technician`, `business`, `seller`, `supplier`,
  and the existing `store` workspace) grant product capabilities.
- Internal roles (`owner`, `super_admin`, `admin`, and `moderator`) grant
  private HDC operational authority. They are never public-registration or
  self-service choices.

Owner and Super Admin can review platform-role applications and manage the
internal department/section structure. Admin is one authority level below
Super Admin. Moderator is community-scoped and cannot manage platform settings.
The auth response uses `platformRoles` and `internalRoles`; `roles` temporarily
mirrors only platform roles for older clients.

The public Role Center and profile overview return platform data only. Private
staff assignments, operational statistics, permission flags, and review tools
are returned only by authenticated `/api/internal/*` routes after a server-side
internal-authority check. The Flutter client exposes the dashboard switch only
when the backend-hydrated session has private access and loads private dashboard
data only after that workspace is opened; the API remains the authoritative
security boundary.

## One-account profile model

Every person signs in through one `hdc_users` account. The account owns one
shared member profile for its master display name, private preferences, bio,
and location. Every active platform role owns a separate role-profile row under
that same user ID, with an independent public name, description, visibility,
public contact, and validated role-specific details.

Changing a Technician public name therefore does not change the Customer,
Seller, Supplier, Business, Store, or master account name. Activating another
role creates another profile, never another login or password. Private staff
assignments remain attached to that account, but are available only inside the
separate private operations dashboard and never as a public marketplace profile.

The workflow bootstrap is filtered by PostgreSQL row-level security. Customers
receive their requests and related proposals; technicians receive eligible
marketplace requests and their own proposals; confirmed transaction data is
visible only to its customer and technician.

## Required server environment variables

- `HDC_DATABASE_URL` (preferred) or legacy `DATABASE_URL`
- `HDC_SESSION_SECRET`

Provider selectors default to `disabled` and never contain credentials:

- `HDC_EMAIL_PROVIDER`
- `HDC_SMS_PROVIDER`
- `HDC_PHONE_VERIFICATION_PROVIDER`
- `HDC_OBJECT_STORAGE_PROVIDER`
- `HDC_PAYMENT_PROVIDER`

Separate recovery and rotation variables are documented in `.env.example` and
the portability runbook.

Optional until the dedicated security inbox and delivery worker are ready:

- `HDC_SECURITY_REVIEW_EMAIL`

Separate-origin Flutter web deployments must set:

- `HDC_WEB_ALLOWED_ORIGINS` — comma-separated exact frontend origins such as
  `https://app.example.com`. Do not include paths or wildcards. Loopback
  `localhost`, `127.0.0.1`, and `::1` origins are allowed for local Flutter
  Chrome development; arbitrary hosted origins remain denied.

The preferred production layout serves Flutter and `/api/*` from one HTTPS
origin. Build it with `HDC_API_BASE_URL=same-origin`; no hosted cross-origin
allow-list entry is then required. See `docs/NETLIFY_DEPLOYMENT.md`.

Map search defaults to OpenStreetMap and requires no API key. Hosting can swap
providers at build time with `HDC_MAP_SEARCH_URL_TEMPLATE`; include `{query}`
where the encoded service area belongs. This is public client configuration,
never a credential.

Never commit real values. Store them in the hosting provider's secret/environment-variable system.

## Active Neon auth-contract migration

`migrations/0001_active_neon_auth_contract.sql` reconciles the active Neon auth
bootstrap with the provider-neutral role contract required by later HDC domain
migrations. It validates all existing role values before changing anything,
creates `hdc_account_role` when absent, removes the bootstrap's incomplete text
check, and converts `hdc_user_roles.role` without replacing users or role rows.

This migration is intentionally separate from the historical Supabase adapter
under `backend/supabase/migrations`. Do not apply that historical migration to
the active Neon schema. Test 0001 on an isolated branch, then apply root
migrations 0001 through 0011 in order.

## Workflow migration

`migrations/0002_workflow_authority.sql` adds the service-request, proposal,
acceptance-handoff, and service-transaction schema. Apply it first on an
isolated Neon branch using the same database role used by `DATABASE_URL`.
The migration creates a restricted `hdc_app` role, grants the runtime role
permission to assume it, enables row-level security, and fails closed when the
existing HDC auth tables are absent.

Before production:

1. Apply the migration on an isolated branch.
2. Run the local checks below.
3. Exercise customer and technician workflows against a preview deployment.
4. Inspect row-level-security behavior and the HDC security audit log.
5. Apply to production and deploy only after the branch verification passes.

## Role-domain migration

`migrations/0003_role_domain_separation.sql` moves legacy admin/super-admin
assignments out of `hdc_user_roles`, adds Supplier, creates the private internal
authority hierarchy, platform-role applications, role notifications, and the
future internal department/section foundation. It deliberately does not invent
an Owner. Bootstrap the first Owner only through a controlled database change
after verifying the intended HDC account ID.

Apply migration 0003 only after the active Neon auth-contract migration 0001
and workflow migration 0002, first on an isolated branch. Deploy the matching
API and Flutter client together so the new role payload and endpoints remain
synchronized.

## Profile migration

`migrations/0004_one_account_role_profiles.sql` creates the shared member
profile and per-platform-role profile tables, backfills existing accounts and
active roles, adds server-maintained timestamps/versioning, and denies direct
public table access. Apply it after migration 0003, first on an isolated branch.
Deploy the matching API 0.5.0 and Flutter Build 10 together so the public-only
role/profile contracts and private-dashboard contract stay synchronized.

## Account-security and structured-application migration

`migrations/0005_account_security_and_structured_role_applications.sql` adds
public member IDs, hashed recovery answers, one-time password-reset tokens, the
private manual recovery queue, versioned role-application answers, scoped
review grants, role-grant provenance, terms evidence, and organization
membership foundations. It upgrades the existing owner-issued reset-token
table in place and preserves account UUIDs and prior reset records.

Apply migration 0005 after migration 0004. Rehearse it on an isolated branch,
rerun it to verify idempotency, and deploy it with API 0.6.0 and Flutter Build
12 so registration, recovery, and role-review contracts remain synchronized.

## Provider-portability migration

`migrations/0006_provider_portability_foundation.sql` adds the HDC migration
ledger, recovery-pepper key IDs, delivery worker leases/idempotency, and a
private non-secret mapping between immutable HDC IDs and replaceable provider
references. It also creates user/organization storage bindings and a resumable
storage-migration queue with worker leases and checkpoints, plus durable data
export manifests. Apply it after migration 0005 on an isolated
PostgreSQL branch, then deploy it with Build 13. It activates no paid provider
by itself.

## Marketplace-listing migration

`migrations/0007_marketplace_listing_dashboard.sql` creates technology product
listings owned by one immutable account UUID and one approved Seller, Supplier,
or Store role profile. It adds optimistic versioning, active/draft/paused/sold/
archived lifecycle states, lifecycle events, and automatic pausing when a
selling role is removed. Apply it after migration 0006 and deploy it with Build
14. It does not activate checkout, payments, receipts, or public catalog search.

## Marketplace purchase-request migration

`migrations/0008_product_catalog_purchase_requests.sql` adds the public active
technology catalog contract and account-scoped buyer/seller purchase requests.
Requests use immutable HDC public references, UUID idempotency, integer
minor-unit totals, optimistic versions, lifecycle events, self-purchase
prevention, bounded per-account submission rates, and seller-owned inventory
allocation. Closing a listing or
deactivating its selling role automatically declines still-pending requests;
accepted historical allocations remain preserved. Apply it after migration
0007 and deploy it together with the Build 15 API and Flutter client.

## Workflow role and private-messaging migrations

`migrations/0009_workflow_role_set_authority.sql` repairs the database owner's
permission to enter the restricted workflow role. Apply it after migration
0008. `migrations/0010_private_transaction_messaging.sql` adds authoritative
accepted-transaction conversations and messages, participant-only row-level
security, immutable message content, read state, storage choice, and the beta
quota. Rehearse 0010 on an isolated branch and deploy it with Build 20.
`migrations/0011_technician_proposal_lock.sql` lets an approved Technician
take the request row lock required for atomic proposal submission while its
false write check continues to prohibit Technician edits to customer-owned
open requests. Deploy it as the Build 20 proposal hotfix after migration 0010.

## Local checks

```bash
npm ci
npm run verify
HDC_FLUTTER_BIN=/absolute/path/to/flutter npm run build:web
```

For local Netlify execution, use Netlify's development command with local environment variables kept outside source control.

## Security notes

- Passwords are hashed with bcrypt before persistence.
- Session tokens are signed server-side and are backed by revocable database sessions.
- Active roles are read from the backend when a session is checked rather than trusting role claims supplied by Flutter.
- Workflow authorization receives platform roles only; internal authority can
  never be inferred from Technician, Business, Seller, Supplier, or Store.
- Public Role Center and profile responses never include internal roles, staff
  assignments, private permission flags, or operational statistics.
- The private dashboard requires a current authenticated internal assignment;
  each statistic and tool is additionally filtered by backend permissions.
- Only backend-hydrated approval authority can approve a platform role.
- Workflow identity, timestamps, offer counts, proposal quality, technician reputation, transaction relationships, and activity history are derived or verified on the server.
- Proposal acceptance closes competing offers and creates the transaction handoff/workspace in one database transaction.
- Private chat is limited to the accepted transaction's authenticated Customer
  and Technician; message authority, moderation, read state, and quota checks
  are enforced again on the server.
- Workflow queries execute as the restricted `hdc_app` role with request-local user and role context enforced by PostgreSQL row-level security.
- Failed login attempts are rate-limited by a keyed identity fingerprint and recorded in the security audit log.
- Recovery answers are normalized, server-peppered, and bcrypt-hashed; plaintext
  answers and per-question match results are never stored, logged, or returned.
- Any two correct recovery answers issue a 15-minute, one-use reset credential.
  A successful password reset revokes every active session for that account.
- Failed automatic recovery creates a private review request without exposing
  answer content. Manual reviewers can authorize a reset but cannot view or
  choose the member's password.
- API responses use generic errors and do not return database credentials or internal exception details.
- Marketplace listings are filtered by the authenticated seller UUID, tied to
  an approved public selling profile, and version-checked on every update.
- Marking an item sold preserves a seller-reported listing state but cannot be
  used as proof of payment, fulfillment, or receipt issuance.
- Public catalog responses expose seller public names and listing references,
  but never seller or buyer account UUIDs. Purchase dashboards are filtered by
  the authenticated participant on the server.
- Only a Customer can submit a purchase request; an account cannot buy its own
  listing. Seller acceptance and buyer cancellation lock and version-check the
  request so competing decisions cannot both succeed.
- CORS echoes only the same origin, a configured exact hosted frontend origin,
  or a narrow local-loopback development origin. Wildcard browser access is
  not enabled.
- The repository intentionally contains no beta account passwords, database URLs, or session secrets.

## Current beta limitations

Email verification, the outbound email delivery worker/provider, stronger
device/session controls, self-service internal-authority management, internal
department mutation endpoints, server-side catalog pagination/advanced search,
payment-confirmed checkout and sales, receipts, fulfillment/disputes, listing
images, buyer/seller commerce messaging, realtime push delivery for private
chat, user-owned chat-storage connectors, and broader platform authorization
checks belong to later HDC backend work. Until email delivery is configured,
manual recovery cases remain available in the private operations dashboard.
