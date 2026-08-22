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

## Endpoints

- `GET /api/health`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/session`
- `POST /api/auth/logout`
- `POST /api/auth/recovery/start`
- `POST /api/auth/recovery/verify`
- `POST /api/auth/recovery/reset`
- `POST /api/auth/password-reset/confirm` (existing-link compatibility)
- `GET /api/roles/overview`
- `POST /api/role-applications`
- `GET /api/internal/dashboard`
- `GET /api/internal/role-applications`
- `PUT /api/internal/role-applications/:id`
- `GET /api/internal/account-recovery`
- `PUT /api/internal/account-recovery/:id`
- `GET /api/profiles`
- `PUT /api/profiles/member`
- `PUT /api/profiles/:role`
- `GET /api/workflow/bootstrap`
- `POST /api/service-requests`
- `PUT /api/service-requests/:id`
- `DELETE /api/service-requests/:id`
- `POST /api/proposals`
- `PUT /api/proposals/:id`
- `DELETE /api/proposals/:id`
- `POST /api/proposals/:id/accept`
- `PUT /api/service-transactions/:id/status`

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

- `DATABASE_URL`
- `HDC_SESSION_SECRET`

Optional until the dedicated security inbox and delivery worker are ready:

- `HDC_SECURITY_REVIEW_EMAIL`

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
migrations 0001 through 0005 in order.

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

## Local checks

```bash
npm install
npm run typecheck
npm test
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
- The repository intentionally contains no beta account passwords, database URLs, or session secrets.

## Current beta limitations

Email verification, the outbound email delivery worker/provider, stronger
device/session controls, self-service internal-authority management, internal
department mutation endpoints, public profile discovery/search endpoints,
private-message authority/realtime delivery, and broader platform authorization
checks belong to later HDC backend work. Until email delivery is configured,
manual recovery cases remain available in the private operations dashboard.
