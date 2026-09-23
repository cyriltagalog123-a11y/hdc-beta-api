# Build 27 closeout and Build 28 handoff

Reviewed baseline: 2026-09-16; later checkpoint: 2026-09-23

The table below records the original PR #34 closeout. The GCash and Maya
support QR cards shipped separately in PR #41 at production revision
`0856e0865922ba6462efb3c9f69c68a17215bc1b`. The remaining stability
corrections are under PR #36 review. See the
[current release checkpoint](build27-stabilization-checkpoint-20260923.md)
for the updated baseline and gates before Build 28.

The public-technician follow-up in PR #34 is deployed. Build 28 is paused while
the owner-requested [stability review](build27-stability-audit.md) completes.

## Confirmed release identity

| Record | Verified value |
| --- | --- |
| Production application | https://hdc-beta-api.netlify.app/ |
| Release | `0.6.4-build.27` |
| Production/main commit | `f113872fc1be6f65e341f23be37658f8b2a32993` |
| Reviewed source tree | `8660fa7cc415ee3a7325309e268059a6dc3011a8` |
| Merged review | [PR #34](https://github.com/cyriltagalog123-a11y/hdc-beta-api/pull/34) |
| Netlify production deploy | `6aa9d8461a063f8ee25b0791`, ready at the production commit |
| Main CI | [HDC CI #307](https://github.com/cyriltagalog123-a11y/hdc-beta-api/actions/runs/34999889042), success |
| Live public smoke check | [PR34 production verification](https://github.com/cyriltagalog123-a11y/hdc-beta-api/actions/runs/35037232759), success |
| Previous production commit | `21e0e08c6a53a459ffb12af0083810297b85ffb2` |
| Rollback branch | `rollback/build27-before-public-technicians-pr34` |

The smoke workflow's own commit differs because it includes verification code;
it explicitly asserted the live revision above. It checked public technician
search/profile privacy and private-route denial. Current main CI passed 186
server tests, 100 Flutter tests, 18 PostgreSQL integrations and a release web build.

## Recovery evidence

A scheduled production backup and complete isolated restore passed on
2026-09-16 against the current PR #34 production baseline.

- Run: [35074309788, attempt 1](https://github.com/cyriltagalog123-a11y/hdc-beta-api/actions/runs/35074309788).
- Artifact: [10437915491](https://github.com/cyriltagalog123-a11y/hdc-beta-api/actions/runs/35074309788/artifacts/10437915491).
- Name: `hdc-encrypted-backup-35074309788-1`.
- Size: 374067 bytes.
- Archive digest: `sha256:a9cfeb76f3cdfe0ccfa37d8af08c055a0d37874839a9eeb469ffbf14ee82e0d2`.
- Artifact expiration: 2026-10-16T08:32:56Z.
- Restore output confirmed that schema and row inventory matched.

The artifact is recovery evidence for this release, not a substitute for the
fresh backup required before the next production release.

## Earlier PR #31 acceptance evidence and boundaries

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
