HDC 0.6.4+17 - SERVICE-REQUEST RELIABILITY HOTFIX
=================================================

PURPOSE
- Restore authenticated service-request and proposal workflows on Neon.
- Make retries safe and expose useful diagnostic references without leaking
  private request content, credentials, or database details.

ROOT CAUSE
- The database owner was a member of the restricted hdc_app role, but Neon's
  PostgreSQL role membership had SET ROLE disabled. The API therefore failed
  before every RLS-protected workflow query even though normal database health,
  account roles, UUIDs, and CORS were valid.

IMPLEMENTED
- Migration 0009 grants explicit SET permission for hdc_app and records the
  migration in the HDC schema ledger.
- Readiness now verifies both database connectivity and workflow authority.
- New service-request screens retain one request ID across retries.
- Concurrent submit taps share the same in-flight operation.
- The backend treats an identical repeated request ID as a successful replay
  and rejects the same ID with different content.
- Every API response carries a safe request reference; workflow failures show
  that reference to the user for support tracing.

RELEASE GATES
1. Apply migration 0009 on an isolated branch.
2. Verify the restricted hdc_app role can insert and remove a diagnostic
   request under RLS.
3. Run migration checks, portability checks, TypeScript, backend tests, Flutter
   analysis, Flutter tests, and the release web build.
4. Preserve a production rollback branch, apply migration 0009, deploy the
   matching Build 17 API/web bundle, and re-run live health and browser checks.

LIVE-TEST LIMITS
- Begin with the Owner and one controlled technician account.
- Do not use real payments or sensitive attachments yet.
- Record the request reference shown by any failure before retrying.
