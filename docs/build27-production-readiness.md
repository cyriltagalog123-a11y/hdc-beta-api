# Build 27 production readiness

Build 27 is a coordinated database, API, and Flutter release. A successful
frontend deploy by itself is not a successful release.

## Reviewed scope

- Public Knowledge Base search, category filters, guide detail, related guides,
  safety/escalation guidance, and service-request handoff.
- Authenticated helpful/not-helpful feedback tied to one published version.
- Internal draft, review, publish, archive, history, and optimistic version
  controls.
- Published-only, Nexus-ready retrieval with generation disabled.
- Migrations `0023` and `0024`, plus knowledge-aware encrypted backup/restore.

No production data is deleted or replaced by these migrations. Starter content
is inserted idempotently and all Build 27 schema changes are additive.

## Verified pre-production facts — 2026-09-07

- The live Netlify application identifies as Build 26.
- The production Neon migration ledger contains 17 entries through `0016`.
- Production therefore requires the reviewed migrations `0017` through `0024`
  in numeric order before the Build 27 application is published.
- A separate empty PostgreSQL 18 database was rebuilt from all 25 checksum-locked
  migrations. It produced four published starter guides, three knowledge
  protection triggers, zero invalid indexes, and zero unvalidated constraints.
- Restricted `hdc_app` mutation, published-slug retention, version immutability,
  published-history retention, and least-privilege knowledge grants were
  exercised successfully on that isolated database.
- A second PostgreSQL 18 rehearsal stopped at the production-equivalent `0016`
  baseline, inserted representative accounts, legacy locations, a service
  request, listing, accepted purchase, event history, and legal records, then
  applied `0017`–`0024`. All pre-existing inventories and legacy values were
  retained, new location guards rejected invalid writes, and the final schema
  had zero invalid indexes, unvalidated constraints, or disabled HDC triggers.

These observations must be rechecked immediately before promotion because the
production database and pull-request head may change.

## Mandatory promotion sequence

1. Freeze one reviewed pull-request head and require green repository,
   TypeScript, Flutter, PostgreSQL integration, secret-scan, dependency-audit,
   and encrypted backup/restore checks on that exact head.
2. Create a fresh encrypted backup of the current production database using the
   current production-compatible workflow. Complete a full isolated restore and
   retain the authenticated manifest and artifact.
3. Record production row inventories, migration ledger, invalid-index count,
   unvalidated-constraint count, and disabled-trigger count.
4. Apply `0017` through `0024` in numeric order over a direct TLS connection.
   Stop on the first error; do not deploy the Build 27 frontend to compensate
   for a migration failure.
5. Verify exactly 25 ledger rows ending at `0024`, four published starter
   articles with version snapshots, three enabled knowledge protection triggers,
   expected `hdc_app` grants, no PUBLIC table access, and unchanged inventories
   for pre-existing authoritative records.
6. Smoke-test public search/detail, published-only visibility, authenticated
   feedback, Admin draft/review limits, Owner/Super Admin publication, stale-edit
   conflict, archive visibility, and Nexus published-only retrieval.
7. Merge only the exact reviewed head. Require main-branch CI to pass on the
   resulting merge commit.
8. Publish Netlify production from that exact merge commit. Verify `/`,
   `/api/health`, `/api/health/ready`, the manifest/startup identity, security
   headers, and the Knowledge Base smoke tests again.

## Rollback boundary

Migrations `0017`–`0024` are additive, so the previous Build 26 application can
remain online while a forward fix is prepared if the Build 27 frontend fails.
Do not run ad-hoc down migrations or delete knowledge rows. If database
integrity is affected, preserve evidence and recover through the validated
encrypted backup/restore procedure or a reviewed Neon restore point.
