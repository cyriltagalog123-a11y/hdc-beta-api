# Build 27 stabilization review — 16 September 2026

Build 28 is paused at the owner's request while the released Build 27 is audited.
The reviewed production commit is `f113872fc1be6f65e341f23be37658f8b2a32993`,
Netlify deploy `6aa9d8461a063f8ee25b0791`, release `0.6.4-build.27`.

## Confirmed baseline

- GitHub main and Netlify production both identify the reviewed commit.
- Local repository checks passed: 25 immutable migrations, release identity,
  portability, TypeScript, 186 server tests; the full dependency audit reported zero vulnerabilities.
- Read-only production checks found 25 migrations through `0024`, no invalid
  indexes, no unvalidated constraints, no disabled HDC triggers, no active
  listings owned by inactive accounts, and no approved active technician missing a profile.
- All seven live readiness checks returned `ok`.
- Scheduled production backup [35074309788](https://github.com/cyriltagalog123-a11y/hdc-beta-api/actions/runs/35074309788)
  passed on 16 September. Its complete isolated restore matched the source schema and row inventory.

## Corrections under review

1. Apply active-account checks to the public catalog and purchase submission,
   and active-selling-role checks to existing seller decision/fulfillment paths.
2. Authorize purchase completion participants before returning a version conflict;
   reject malformed purchase IDs and versions with a validation response.
3. Reject reuse of a purchase idempotency key with different details and serialize
   a buyer's concurrent submissions and rate-limit accounting.
4. Invalidate seller responses after role changes, reject duplicate listing saves
   and mismatched-owner save responses, and prevent older reads from replacing
   newly saved listings or cancelled requests.
5. Preserve a listing's currency in the existing editor and fit long selling
   profile names and purchase statuses on compact screens.
6. Update stale release handoff evidence and add a reusable read-only live smoke check.

These changes keep Build 27's version and state machine. They add no schema
migration, fulfillment feature, photo storage, cart, or payment processing.
New regression coverage exercises real PostgreSQL acceptance races, retry
semantics, monetary immutability, account/role isolation, and Flutter async state.
Candidate CI, responsive checks and release evidence are recorded below when complete.

---

# Build 27 stability audit — 9 September 2026

## Production baseline

Audited `432e34a1c68bb865a04a82bb852ef6d1caa35800` on `main`, published by Netlify deploy `6aa132b30b820500073ad7fe`. PR #29 had already corrected the stale splash label and expanded release-marker validation before this audit. Historical build references in documentation and source comments are retained.

The live root, version manifest, API health, API readiness, and public Knowledge Base returned HTTP 200. The protected Knowledge Base management endpoint returned HTTP 401 without authentication. The app manifest reports version `0.6.4`, build `27`; API health reports `0.6.4-build27`. All seven readiness checks passed: database, workflow authority, private messaging, transaction tools, authentication bootstrap, legal records, and latest schema. Security headers and no-store API responses were present.

Read-only production catalog checks found all 25 migrations through `0024`, zero invalid indexes, zero unvalidated constraints, zero disabled HDC triggers, and all three Knowledge Base protection triggers enabled. No production records were created or changed to perform these checks.

## Corrections

- Give existing Flutter service-worker registrations an update identifier derived from the source revision, compiled application, and worker contents. Several patches can share Build 27; their cache identifiers must still change when the application or its assets change. The revision covers asset-only changes when Flutter emits a cleanup stub without a resource manifest. Expose the source revision and cache identifier in a non-cacheable `hdc-release.json`.
- Apply the workflow API's 25-second network timeout to both response headers and the complete response body.
- Ignore community, news administration, and platform-role responses from previous account or role bindings. Ignore obsolete searches and responses arriving after provider disposal.
- Reset marketplace saving state when the account changes so a previous account's request cannot leave the new account blocked.
- Refresh news after a successful write even when a pre-write read is pending, and prevent duplicate news/role writes while a request is in progress.
- Clear stale Knowledge Base category counts after a failed search and invalidate searches on disposal.

These changes preserve Build 27's version, data model, API authority, publishing history, and dependency lockfiles. They require no database migration.

## Verification and release gates

Focused regression coverage exercises out-of-order responses, account changes during requests, role revocation, provider disposal, duplicate writes, stalled response bodies, and distinct cache identifiers for patches sharing a build number. The repository verification also covers release synchronization, migration immutability, portability, TypeScript, and backend unit tests.

Before promotion, require the full pinned Flutter analysis/test/release build and PostgreSQL clean-install, upgrade, workflow-isolation, and encrypted restore jobs. Production promotion must preserve a rollback branch and a successful encrypted backup, then match the merge revision across `main`, CI, Netlify, and the live release manifest. Record the final run and deployment identifiers in the review PR.

## Remaining product work

The product-passport timeline and audit panels still describe future integrations, and the role-onboarding preview includes a future continuation. They are planned UI work, not version mismatches. Resolve their intended scope before implementing those features. Authenticated production workflows were not exercised with test writes; isolated automated workflow tests provide that coverage.
