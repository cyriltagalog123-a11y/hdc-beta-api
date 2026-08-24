HDC 0.6.4+13 - PROVIDER PORTABILITY AND RECOVERY FOUNDATION
================================================================

PURPOSE
- Preserve HDC-owned IDs, data, and security controls when hosting, database,
  email, SMS, storage, or payment providers must change.
- Use an economical cold-standby strategy instead of costly active-active
  infrastructure during beta.

IMPLEMENTED
- Central provider-neutral runtime environment reader.
- Standard Web Request/Response API entry point for alternate hosting adapters.
- Provider-independent normal/read-only/maintenance/incident operation modes.
- PostgreSQL driver contract and dependency-aware readiness endpoint.
- Email/SMS, object-storage, and payment provider contracts.
- Provider selector validation with safe disabled/queued/fail-closed defaults.
- Migration 0006: schema ledger, recovery pepper key IDs, delivery worker
  leases/idempotency, private external-provider reference mapping, and
  user/organization storage bindings, resumable migration checkpoints, and
  portable data-export manifests.
- Separate rotatable session and recovery secrets with legacy verification.
- Encrypted PostgreSQL backup and archive-verification tools.
- CI portability boundary check preventing provider SDKs and server secrets
  from leaking into Flutter or bypassing approved adapters.
- Migration, cutover, rollback, key-rotation, and backup runbook.

NOT ACTIVATED
- No paid provider is enabled.
- No live hosting or database provider was switched.
- No production migration or deployment was performed by this package.
- Private chat remains local until the backend messaging/storage sprint.

RELEASE CHECKS
1. flutter pub get
2. flutter analyze
3. flutter test
4. npm ci
5. npm run verify
6. Apply migration 0006 on an isolated PostgreSQL branch before deployment.
7. Verify GET /api/health/ready on the candidate deployment.

See docs/PORTABILITY_AND_RECOVERY.md for the complete operational runbook.
