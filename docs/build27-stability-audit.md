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
