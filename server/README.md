# HDC Server Portability Layer

This directory contains provider-neutral server code. It must not depend on a
hosting company or expose provider credentials.

- `core/environment.mts` is the single runtime environment boundary.
- `core/operation-mode.mts` provides normal, read-only, maintenance, and
  incident gates without depending on a provider dashboard.
- `core/security-keys.mts` owns key IDs, rotation, and compatibility.
- `core/provider-config.mts` validates non-secret provider selections.
- `core/provider-registry.mts` resolves only explicitly registered adapters.
- `contracts/` defines PostgreSQL lifecycle, outbound delivery, phone
  verification, object storage, user/organization storage migration, portable
  exports, and payment behavior that future adapters must satisfy.

An adapter belongs outside `core/` and `contracts/`. It may import its provider
SDK, but HDC domain code may import only the contract. External IDs must be
recorded in `hdc_external_provider_references`, never used as HDC entity IDs.

`adapters/node-http.mts` is the prepared transport wrapper for a conventional
Node server or container. The active Netlify wrapper and a future Node wrapper
both call the same `handleHdcApiRequest` Web handler.

New adapters require contract tests, disabled/degraded behavior, idempotency,
secret-store documentation, health checks, migration rehearsal, and rollback
instructions before activation.
