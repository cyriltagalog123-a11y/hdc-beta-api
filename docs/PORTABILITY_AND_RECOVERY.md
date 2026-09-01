# HDC Provider Portability and Recovery Runbook

## Purpose

HDC must survive a hosting outage, provider price change, account suspension,
service shutdown, or planned move without changing its internal IDs or exposing
provider credentials to Flutter. Build 13 establishes the contracts and
operational rules; it does not activate paid providers or automatic failover.

The economical beta model is a **cold standby**: verified encrypted backups,
portable source, a prepared alternate deployment procedure, and manual cutover.
Running two writable production databases is intentionally prohibited because
split-brain data is more dangerous than a short maintenance window.

## Permanent boundaries

| Capability | HDC boundary | Current adapter | Migration rule |
| --- | --- | --- | --- |
| Client API | HTTPS/Web Request and Response | Netlify Function wrapper | Publish through an HDC-owned API domain before public launch |
| Database | PostgreSQL protocol and ordered SQL migrations | `postgres` driver | Move only to a tested PostgreSQL-compatible destination |
| Email/SMS | Transactional outbox and delivery contract | Disabled | Queue safely until an adapter is configured |
| Phone verification | Challenge/verification contract | Disabled | Fail closed; a provider outage cannot verify an account |
| Object storage | Object-storage contract | Disabled | HDC IDs stay stable; provider object IDs stay in the private mapping table |
| Payments | Payment contract with minor-unit amounts and idempotency | Disabled | Fail closed; never infer payment success from the client |
| External IDs | `hdc_external_provider_references` | PostgreSQL | External references never become HDC primary keys |
| Portable exports | Versioned export jobs and SHA-256 manifests | Disabled | Generate in isolation, verify the manifest, then transfer through an object-storage adapter |

Provider credentials belong only in the runtime secret store. They must never
be stored in Flutter, committed source, migration files, provider metadata, or
the external-reference table.

## Runtime configuration

`HDC_DATABASE_URL` is the preferred PostgreSQL connection variable.
`DATABASE_URL` remains a temporary compatibility fallback. The active database
driver is `postgres`; supporting every SQL/NoSQL engine is not a goal because it
would weaken correctness and greatly increase cost.

The following selectors contain adapter names, not secrets:

- `HDC_EMAIL_PROVIDER`
- `HDC_SMS_PROVIDER`
- `HDC_PHONE_VERIFICATION_PROVIDER`
- `HDC_OBJECT_STORAGE_PROVIDER`
- `HDC_PAYMENT_PROVIDER`

All default to `disabled`. Email and SMS work is queued. Phone verification,
object storage, and payments fail closed until a verified adapter exists.

`HDC_OPERATION_MODE` is HDC's provider-independent safety control:

- `normal`: standard operation.
- `read_only`: GET/HEAD routes remain available and writes return 503.
- `maintenance`: only liveness/readiness routes remain available.
- `incident`: same traffic restriction as maintenance, with a distinct audit
  and operator meaning.

## Key rotation without account loss

Session signing and recovery-answer peppering are separate in Build 13.

1. Keep the current `HDC_SESSION_SECRET` available.
2. Before introducing `HDC_RECOVERY_PEPPER`, copy the former session secret to
   `HDC_RECOVERY_LEGACY_PEPPER` in the secret store.
3. Set `HDC_IDENTITY_FINGERPRINT_SECRET` to stable independent key material so
   login/recovery throttling fingerprints do not change with session rotation.
4. Set a new `HDC_RECOVERY_PEPPER` and `HDC_RECOVERY_PEPPER_KEY_ID`.
5. Deploy migration `0006` before code that writes `pepper_key_id`.
6. Recovery answers are gradually rewritten with the current pepper when a
   member updates them. Plaintext answers are never needed.
7. To rotate the session key without abruptly ending valid sessions, move the
   former value to `HDC_SESSION_SECRET_PREVIOUS`, assign its previous key ID,
   then configure the new current key. Remove the previous key after the
   maximum session lifetime has passed.

Never rotate or delete a recovery pepper until the database proves that no
answer rows still reference its key ID.

## Encrypted PostgreSQL backups

Requirements: Node.js 20+, `pg_dump`, `pg_restore`, a direct (unpooled)
database URL, and a base64-encoded 32-byte encryption key stored separately
from the backup. For Neon, the backup URL hostname must not contain
`-pooler`; application runtimes may continue using their separate pooled URL.

Generate an encryption key once and put it in the secret manager, not source:

```bash
node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
```

Create and verify an encrypted custom-format archive:

```bash
npm run backup:postgres -- --output /absolute/secure/backup-directory
npm run verify:backup -- --backup /absolute/path/file.hdcbackup
```

Verification checks the encrypted-file checksum, AES-256-GCM authentication,
and the PostgreSQL archive catalog. A backup is not considered valid until this
verification succeeds. Keep the encryption key in a different account/location
from the backup.

Recommended low-cost schedule during beta:

- Before every schema migration or production deployment.
- One encrypted backup nightly when real beta data exists.
- Retain 7 daily, 4 weekly, and 3 monthly copies as budget permits.
- Verify every backup automatically.
- Perform a full restore drill to an isolated database at least monthly.

## PostgreSQL provider cutover

1. Announce maintenance, set `HDC_OPERATION_MODE=read_only`, and confirm writes
   return 503. Do not allow two writable primary databases.
2. Create and verify a final encrypted backup.
3. Restore into an isolated destination PostgreSQL database with no public
   application traffic.
4. Confirm migration ledger versions, row counts, UUID uniqueness, foreign
   keys, row-level-security policies, Owner access, and audit history.
   For a selective move, also generate and verify a versioned HDC export
   manifest; never treat an unverified export as a backup.
5. Deploy the candidate API with `HDC_DATABASE_URL` pointing to the destination.
6. Require `GET /api/health/ready` to return ready, then test login, recovery,
   profile isolation, role review, request creation, proposals, and acceptance.
7. Switch the HDC-owned API hostname to the candidate deployment.
8. Keep the former database read-only for the rollback window.
9. If validation fails, return the hostname to the former deployment. Never
   merge two independently written databases by hand.

## Hosting provider cutover

The exported `handleHdcApiRequest(Request)` function is the portable API entry
point. A hosting adapter supplies a standard Web `Request`, returns its
`Response`, and provides server environment variables. Domain logic must not
import a hosting SDK. The current Netlify default export is only one wrapper.

Before distributing public builds, point Flutter at an HDC-owned API hostname.
Changing the service behind that hostname then requires DNS/deployment work,
not a new APK/EXE solely because a hosting company changed.

## External paid-service cutover

Every adapter must satisfy these rules before activation:

- Credentials and webhook secrets are server-only.
- Each write has an HDC idempotency key.
- Provider webhooks are cryptographically verified and replay-protected.
- HDC records the normalized outcome before notifying the client.
- External references are stored separately from immutable HDC IDs.
- A disabled, degraded, or queued state is explicit.
- Provider failure cannot grant a role, mark a payment successful, or expose a
  private object.
- Migration is rehearsed with a non-production account and rollback plan.

## Current limitations

- No email, SMS, phone-verification, object-storage, or payment adapter is active.
- Private conversations remain device-local and are not yet authoritative
  backend records.
- Backups are tool-assisted but not yet scheduled by infrastructure.
- `/api/health` is liveness only; `/api/health/ready` verifies PostgreSQL.
- Netlify and the active PostgreSQL host remain the current live providers until
  an explicitly approved migration.
