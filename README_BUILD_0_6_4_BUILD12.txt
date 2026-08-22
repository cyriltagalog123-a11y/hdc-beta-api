HDC 0.6.4+12 - STRUCTURED ROLE APPLICATIONS AND ACCOUNT RECOVERY
=================================================================

What changed
------------
- Registration now requires three private account-recovery answers plus the
  current HDC Beta Terms and Privacy acceptance.
- Forgot Password asks all three questions. Two or three correct answers create
  a 15-minute, single-use reset authorization. The server never reveals which
  answers matched.
- Fewer than two correct answers creates a private manual review request for the
  Owner or a specifically authorized reviewer. No recovery answer is included
  in notifications or review records.
- Elevated public platform roles now use role-specific structured application
  fields. Internal roles remain private and cannot be selected or requested.
- Reviewers can approve, reject, or request changes. Approval records the source
  application and reviewer on the public role grant.

Security boundaries
-------------------
- HDC users retain unique UUID authentication identities. Public member IDs are
  separate display identifiers and are never authorization credentials.
- Recovery answers are normalized, HMAC-peppered with the server secret, then
  bcrypt-hashed. Only hashes are stored.
- Reset credentials are SHA-256 digests at rest, single-use, expire after 15
  minutes, and revoke every active session after a successful password change.
- Recovery throttling and all decisions are written to the security audit log.
- Manual approval never lets a reviewer choose or see a member's password.
- Every business/store staff member keeps an individual HDC UUID. Organization
  access uses explicit memberships; shared logins are not supported.

Email status
------------
The owner has not configured the future dedicated security-review inbox or a
verified delivery provider yet. Manual cases are fully retained in the private
dashboard. HDC_SECURITY_REVIEW_EMAIL enables the provider-neutral outbox target;
an email worker/provider must still be configured before claiming delivery.

Validation
----------
- npm run typecheck: pass
- npm test: 32/32 pass
- migration 0005 isolated Neon rehearsal: pass
- migration idempotency rerun: pass
- Flutter/Dart SDK is not installed in this workspace; run flutter analyze and
  flutter test after clean extraction before producing device binaries.
