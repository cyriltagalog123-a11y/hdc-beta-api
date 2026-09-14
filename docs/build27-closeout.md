# Build 27 closeout and Build 28 handoff

Reviewed: 2026-09-14

Status: production release and automated acceptance evidence verified.
This closeout records the deployed baseline and the selected preparation work
before Build 28. It does not start shop implementation.

## Confirmed release identity

| Record | Verified value |
| --- | --- |
| Production application | https://hdc-beta-api.netlify.app/ |
| Release | `0.6.4-build.27` |
| Production/main commit | `21e0e08c6a53a459ffb12af0083810297b85ffb2` |
| Reviewed source tree | `40e9ae3ab3cf435a680978a5b7a4f503d0dc1d02` |
| Merged review | [PR #31](https://github.com/cyriltagalog123-a11y/hdc-beta-api/pull/31) |
| Netlify production deploy | `6aa80c036df475000850e905`, ready at the production commit |
| Main CI | [HDC CI #301](https://github.com/cyriltagalog123-a11y/hdc-beta-api/actions/runs/34859292247), success |
| Live public smoke check | [PR31 production smoke verification](https://github.com/cyriltagalog123-a11y/hdc-beta-api/actions/runs/34859735212), success |
| Previous production commit | `028a6a2f0d650394d651d12d927e73fb496cd059` |
| Rollback branch | `rollback/build27-before-operations-pr31` |

The smoke workflow is isolated on `codex/verify-pr31-production`. Its commit
differs from the application commit because it contains the verification
workflow. The test explicitly asserted the live application's revision was
`21e0e08c6a53a459ffb12af0083810297b85ffb2`.

## Recovery evidence

A fresh production backup and complete isolated restore passed on
2026-09-14 before the release merge.

- Run: [34327269606, attempt 4](https://github.com/cyriltagalog123-a11y/hdc-beta-api/actions/runs/34327269606).
- Artifact: [10354136981](https://github.com/cyriltagalog123-a11y/hdc-beta-api/actions/runs/34327269606/artifacts/10354136981).
- Name: `hdc-encrypted-backup-34327269606-4`.
- Size: 373823 bytes.
- Archive digest: `sha256:513fd09d5522d078fc9389d6a01694f661527f3960fb4e037d671d23df1c7e50`.
- Artifact expiration: 2026-10-14T14:59:26Z.
- Restore output confirmed that schema and row inventory matched.

The artifact is recovery evidence for this release, not a substitute for the
fresh backup required before the next production release.

## Acceptance evidence and boundaries

| Area | Verified evidence |
| --- | --- |
| Owner operations | PostgreSQL tests open every snapshot, page member records, fetch individual details and deny unauthorized drill-down. |
| Knowledge Base attribution | PostgreSQL tests verify creator, review submitter and publisher attribution. |
| Report account isolation | Flutter tests reject mismatched-account responses and discard pending results after logout/account changes. |
| Profile privacy | Flutter tests keep account email out of role previews, close previews on logout and reject reads/writes for another account or role. |
| Profile saves | Flutter tests reject duplicate saves and late results after account changes. |
| Repository verification | Main CI passed 178 server/unit tests; 17 credential-dependent tests were skipped in that job. |
| Database integration | The separate PostgreSQL job passed all 16 integration tests and its encrypted backup/restore rehearsal. |
| Flutter | Analyzer reported no issues; all 95 tests and the release web build passed. |
| Live public routes | Root and API liveness returned 200; release revision/version matched production. |
| Live readiness | All seven checks returned `ok`: database, workflow authority, private messaging, transaction tools, authentication bootstrap, legal records and latest schema. |
| Live private-route boundary | An unauthenticated operations-report request returned 401. |
| Live headers | Security headers and the checked no-store cache policies passed. |

Private user journeys were verified through automated Flutter and isolated
PostgreSQL coverage. This closeout did not perform authenticated owner actions
or create transaction records in production. No unresolved failure was found
in the reviewed evidence; this is not a claim that every possible user journey
was manually tested.

The original Build 27 database rollout in
`build27-production-readiness.md` is historical. PR #31 required no migration.
Future releases must inspect the current migration ledger and apply only their
reviewed pending migrations.

## Selected next step

Finish the Build 27 closeout and define the shop's core transaction rules before
expanding Build 28. Reuse the existing commerce records, provider and role
authorization described in `build28-shop-technology.md`.

Recommended Build 28 design defaults to validate against the existing state
machine during its initial audit:

1. **Stock:** allocate available quantity when the seller accepts a request.
   A submitted request must not imply a guaranteed reservation. Define eligible
   cancellation/release behavior atomically with the status change; do not add
   timed cancellation until payment and fulfillment interactions are specified.
2. **Fulfillment:** explicitly record seller-supported pickup/delivery, agreed
   location, fee and timing in the purchase agreement. Preserve the agreement
   when a listing is edited later.
3. **Photos:** identify a supported storage path and its current quota before
   enabling uploads. Use a small configured photo limit, compression and
   server-side file validation. Storage-provider selection remains part of the
   initial Build 28 audit; this note does not claim a provider is configured.

Build 28's primary acceptance journey is browse → request → seller acceptance
→ fulfillment → recorded completion, including cancellation and failure paths.
Its implementation and production promotion follow the repository release
policy. This documentation introduces no shop behavior, migration or deployment.
