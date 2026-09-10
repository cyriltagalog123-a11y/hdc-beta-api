# HelpDesk Connect delivery roadmap

Last updated: 2026-09-07

## Delivered baseline

- Builds 12–19: provider-neutral accounts, role workspaces, profiles,
  marketplace foundations, service requests, and technician discovery.
- Build 20: authoritative cross-account requests, proposals, accepted services,
  and participant-only chat.
- Builds 20.1A–20.1B: notifications, incremental chat, schedules, price changes,
  and service exceptions.
- Builds 21–22: external-payment evidence, receipts, transaction documents, and
  disputes with authorized resolution.
- Build 22.1: database/legal hardening, fail-closed provider selection,
  transaction retention, required integration coverage, automated backups, and
  restore rehearsal support.

## Delivered responsive milestone — Build 24A

Build 24A migrates the Customer request and Technician discovery experience to
the responsive HDC interface foundation. It covers request intake, review,
Customer request records, request details, and the approved public Technician
directory without changing database schemas or workflow authority.

Acceptance gates:

1. Request validation, publication, editing, cancellation, and refresh retain
   their existing provider-backed behavior.
2. Every received offer remains reachable from both the Customer request list
   and request record; accepted work opens the existing service workspace.
3. Technician search lists only approved public profiles and never invents
   ratings, exact distances, or private account information.
4. Customer request and discovery layouts work without horizontal overflow on
   compact screens and use two-column working surfaces when space permits.
5. Flutter analysis/tests, API tests, release synchronization, and the web
   production build pass before deployment.

## Delivered responsive milestone — Build 24B

Build 24B continues the same migration through Technician opportunities,
proposal creation, the Customer offer inbox, comparison, and acceptance. It
also adopts the approved blue HDC hexagon-and-H mark across the Flutter brand
lockup, startup shell, favicon, and installable web-app icons.

Acceptance gates:

1. Technician opportunity discovery remains provider-backed, account-scoped,
   filterable, and usable on compact and wide layouts.
2. A Technician can save and resume one draft, but cannot submit a second offer
   for the same issue after the first offer is recorded.
3. Every Customer offer remains reachable; shortlist, comparison, details, and
   acceptance retain the existing authoritative proposal workflow.
4. Comparison cards stack on compact screens instead of requiring horizontal
   page scrolling, and all offer/acceptance actions remain reachable.
5. The approved HDC logo is packaged locally with no remote-image dependency;
   maskable icons retain safe padding around the full hexagon.
6. Flutter analysis/tests, API tests, release synchronization, and the web
   production build pass before deployment.

## Delivered responsive milestone — Build 24C

Build 24C migrates Customer active services, Technician jobs, and the shared
Service Workspace to the responsive HDC interface. It does not change database
schemas or server-authorized workflow transitions.

Acceptance gates:

1. Customer, Technician, and combined workspace lists remain account-scoped,
   retain every active and historical transaction, and sort by latest activity.
2. All, Active, Your action, and History views clearly identify the recorded
   participant role without changing transaction status or hiding records.
3. A workspace fails closed before showing transaction details when the current
   account is not a participant or the requested role does not match the role
   recorded on the transaction.
4. Accepted terms, participants, service progression, Nexus guidance, timeline,
   existing participant tools, and the correct next action remain reachable on
   compact and wide layouts without horizontal page scrolling.
5. Status changes continue through the existing provider and server-authorized
   transition gateway; compact-screen controls prevent accidental double action
   while a transition is saving.
6. Flutter analysis/widget tests, API tests, PostgreSQL workflow isolation,
   encrypted backup/restore, release synchronization, and the production web
   build pass before deployment.

## Build 24 completion sequence

Builds 24D–24I finish the responsive migration without adding new database
schemas, bypassing provider authority, or weakening the Build 22.1 security and
retention baseline.

### Build 24D — Private transaction chat

- Fail closed before exposing transaction context or participant messages.
- Preserve participant-authorized access, refresh/read state, moderation,
  idempotent sends, ordering, draft retry identifiers, and bounded foreground
  refresh.
- Keep transaction context, storage usage, message history, retry state, and the
  composer usable on compact and wide layouts.
- Describe HDC-managed quota and unavailable user-owned storage accurately.

### Build 24E — Payment evidence and receipts

- Preserve the external-payment evidence model: HDC does not hold or process
  money in this release.
- Keep customer record, technician confirmation/rejection, refund recording,
  customer refund confirmation, balances, events, and participant-confirmed
  receipts reachable on compact and wide layouts.
- Freeze payment mutations while a dispute is active and retain authoritative
  transaction/provider checks.

### Build 24F — Transaction documents

- Preserve protected structured text records and integrity metadata.
- Keep service reports, warranty terms, payment evidence, receipt notes, and
  dispute evidence readable and actionable without horizontal overflow.
- Do not imply binary-upload support until an object-storage provider is
  explicitly connected.

### Build 24G — Disputes

- Preserve the server-authorized dispute lifecycle and service/payment freeze.
- Keep reason, requested outcome, case notes, withdrawal, history, closed cases,
  and authorized resolution records reachable across compact and wide layouts.
- Do not expose admin resolution authority to ordinary participants.

### Build 24H — Profiles and platform roles

- Preserve one-account/multiple-profile identity boundaries and active-role
  authorization.
- Keep member profile, security entry point, workspace profile selection, role
  status, applications, review state, and notifications reachable on compact
  and wide layouts.
- Do not expose private internal-role review data through public profile views.

### Build 24I — Commerce

- Preserve provider-backed catalog, seller inventory, purchase requests,
  acceptance/cancellation, stock allocation, and recorded commerce state.
- Keep search/filter, responsive product cards, buyer purchase tracking, seller
  sales tools, listing controls, and product records usable without horizontal
  page scrolling.
- Do not claim that HDC processed payment or verified delivery where the
  connected provider/workflow has not done so.

## Build 24 final release gate

Build 24 is ready for review only after 24D–24I responsive regressions pass with
Flutter analysis/widget tests, API tests, PostgreSQL isolation, encrypted
backup/restore rehearsal, release synchronization, and the production-shaped
web build. Merge to `main` and production deployment remain separate explicit
approval gates.

## Delivered interface and hardening milestones — Builds 25–26

- Build 25 completed the application-wide HDC visual and interaction redesign
  while preserving provider authority, account isolation, and responsive
  behavior.
- Build 26 consolidated registration, controlled-location, release, News
  history, recognition-consent, and CI/deployment hardening as the prerequisite
  for public knowledge.

## Build 27 — Versioned HDC Knowledge Base

Build 27 activates public Knowledge Base discovery, safe troubleshooting
guides, related guidance, authenticated helpfulness feedback, and handoff into
the existing service-request flow. It adds a versioned internal authoring and
publication workflow and makes published HDC content available to Nexus only as
retrieval material; it does not authorize generated troubleshooting claims.

Release gates:

1. Public results contain only published snapshots and preserve the last public
   version while a newer draft or review is prepared.
2. Admin may draft and request review; only Owner and Super Admin may publish,
   archive, or reopen archived knowledge.
3. Published slugs and version history are immutable and retained; stale editor
   updates return a version conflict instead of overwriting newer work.
4. Feedback is authenticated, unique per member/article/version, and rejects a
   version that changes during submission.
5. The four starter guides include safety and escalation boundaries, and Nexus
   retrieval remains limited to published, Nexus-ready HDC content with
   generation disabled.
6. All 25 migrations rebuild cleanly on PostgreSQL 18, restricted-role grants
   and knowledge triggers pass, encrypted backup/restore includes knowledge
   inventory, and Flutter/API/release/deploy-preview checks are green.
7. Production promotion follows the reviewed sequence in
   `docs/build27-production-readiness.md`; a frontend-only deploy is not a
   successful Build 27 release.

### Build 27 operations and profile follow-up

Make every private operations snapshot open its authorized records and individual
details. Show Knowledge Base creator, review submitter and publisher attribution
directly in operations. Improve member-profile completeness, visibility and role
profile previews. See `docs/build27-operations-reports.md` for behavior and gates.

## Build 28 — Shop Technology

Prepare the existing commerce foundation for a clearer catalog, product details,
seller inventory workspace and buyer purchase history. Preserve server stock,
role, participant and payment authority. Delivery order, open decisions and
acceptance gates are recorded in `docs/build28-shop-technology.md`.

This is a planned next build; the Build 27 follow-up does not change shop code.
