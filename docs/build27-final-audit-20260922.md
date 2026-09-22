# Build 27 final stability audit — 22 September 2026

This continues PR #36. Build 28 remains paused until the stability release is
verified. The production baseline was `f113872fc1be6f65e341f23be37658f8b2a32993`
on Netlify deploy `6aa9d8461a063f8ee25b0791`. The recovered PR #36 candidate
`feaa585d469b0c231faaf5a507467e11db019038` matched local tree
`70550fefa1a73626d62677bb9de218db97eecbcc`.

## Scope and findings

| Area | Evidence and result |
| --- | --- |
| Hosting and connections | Production/main revision match. The live root, health, readiness, technician directory/profile and private-route denial checks passed again on 22 September in run 35037232759. All seven readiness checks passed. |
| Database | Read-only catalog audit: 25 migration entries through 0024; zero invalid HDC indexes, unvalidated constraints or disabled HDC triggers. No missing member profiles, approved technician profiles or public member IDs. No active listings attached to inactive accounts/roles. |
| Database privileges | `hdc_app` has no superuser, create-role, create-database or RLS-bypass privileges. PUBLIC has no HDC table grants. |
| Accounts and security | Existing active-account/session/role checks and recovery flows reviewed. Found concurrency gaps in sign-in, recovery verification and recovery-answer update throttles; corrected with transaction-scoped advisory locks around each identity's limit check and outcome. |
| Commerce | Retains PR #36 fixes for seller authority, purchase privacy, idempotency payload checks, simultaneous stock allocation, currency retention, stale listing reads and compact layouts. |
| Notifications | Fixed loading state stuck after account changes, old reads overwriting read acknowledgments, and page-sized unread totals replacing the server-wide count. Rejects mismatched acknowledgment records. |
| Service workspace | Fixed saving state stuck after account changes; older toolbox reads no longer replace a newer read or successful payment/document/dispute change. Concurrent loading state is tracked per transaction. |
| UI | Browser inspection of production sign-in, guest introduction/dashboard and technician discovery succeeded. The review build renders. Compact commerce/profile/workspace behavior is exercised by Flutter widget tests. |
| Backups | Daily encrypted backup/full restore runs succeeded on 17–22 September. Run 35705059860 restored matching schema and row inventory; artifact 10684072321, 376106 bytes, SHA-256 `92cb4cd52f8c1086a255e8243d159eaedfa870ace193452306ec2704db495021`. Require another fresh backup before promotion. |
| Logs | Reviewed CI, dependency audit, deployment metadata, backup/restore logs, browser errors and aggregate security-audit outcomes. No application error appeared in the inspected browser flows. Historical Netlify function request logs are not exposed by the connected tools and are not claimed as fully reviewed. |
| Structure and planning | Provider portability and source release markers checked; Flutter is pinned to 3.47.1, runtime Node 24. Product-passport timeline/audit panels and role-onboarding continuation still identify future work. Shop Technology remains Build 28 scope. |

## Verification boundaries and unfinished capabilities

- Email/SMS delivery, phone verification, object storage and payment processing
  adapters remain disabled. Email verification and two-factor authentication
  are not implemented/active and must not be represented as completed controls.
  Recovery answers and manual private recovery review are the existing paths.
- Netlify exposes configured production and preview database/session-secret
  contexts, with secret values masked. The actual preview database target and
  separation cannot be certified from those masked values. All destructive
  integration checks run on isolated CI PostgreSQL services.
- Independent recovery-pepper and identity-fingerprint environment variables
  are absent from the returned configuration. Existing legacy-key fallback is
  retained; rotating keys without preserving legacy recovery material could
  lock out accounts. Plan key separation alongside account-security work.
- The production migration ledger records all 25 versions but has null recorded
  checksums. Repository migration hashes pass; that is not proof of historical
  applied-file hashes. Do not backfill guessed hashes. A future migration runner
  should record the checksum of the exact file it applies.
- Daily backup artifacts have 30-day retention. Separate long-term/off-account
  retention and independent custody of the encryption key are not verified.
- No real-account credentials were used and no production customer records were
  created or changed for this audit. Authenticated journeys are verified in
  isolated PostgreSQL and Flutter tests, not asserted as manual production tests.

## New regression coverage

- Notifications: account changes during a read, stale reads after single/all
  acknowledgments, unread totals exceeding the loaded page, late old-account
  writes, mismatched responses and disposal.
- Service tools: account changes during payment save, independent concurrent
  reads, response ordering, reads started before/during writes, wrong transaction
  responses and disposal.
- Authentication: concurrent requests at the fifth-attempt boundary for login,
  recovery verification and recovery-answer changes; successful answer updates
  and one-time recovery credentials; separate limits for separate actions.

The update adds no database migration, dependency, provider, account reset,
payment processing or Build 28 feature. Exact final CI, preview, backup,
rollback, merge and production verification evidence belongs in PR #36 after
the new revision completes its gates.
