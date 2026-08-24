# HDC Architecture Decisions

This document records major architectural decisions made during the development of HDC.

---

## ADR-001

Enterprise Event Bus

Status: Accepted

Reason:
All modules communicate through events instead of direct dependencies.

---

## ADR-002

Passport Framework

Status: Accepted

Reason:
Every major entity uses a consistent Passport experience.

---

## ADR-003

Nexus AI

Status: Accepted

Reason:
Nexus serves as the platform-wide intelligent assistant with access to enterprise knowledge and analytics.

---

## ADR-004

Marketplace Architecture

Status: Accepted

Reason:
Marketplace is implemented as the HDC Commerce Engine rather than a standalone shopping module.

---

## ADR-005

Private Operations Workspace Boundary

Status: Accepted

Reason:
Public role and profile surfaces expose platform workspaces only. Backend-hydrated
internal authority grants access to a separate private dashboard, whose API
performs its own access check and filters every statistic and action by explicit
permissions. Client-side switch visibility is navigation only and is never an
authorization boundary.

---

## ADR-006

Provider Independence and Economical Recovery

Status: Accepted

Reason:
HDC domain IDs, authorization, workflow state, and audit evidence must remain
owned by HDC. Hosting, PostgreSQL hosting, email, SMS, object storage, and
payment companies are replaceable adapters. Provider credentials remain in the
runtime secret store, provider references never become HDC primary IDs, and
external writes use queues or fail-closed contracts. During beta, verified
encrypted backups and a rehearsed cold standby are preferred over expensive
active-active infrastructure. Two writable primary databases are prohibited.

---

## ADR-007

Marketplace Listing Ownership and Sold-State Semantics

Status: Accepted

Reason:
Every technology product listing belongs to one immutable HDC account UUID and
one approved Seller, Supplier, or Store role profile. Internal authority never
grants selling rights. Listing status and stock are server-authoritative and
version-checked. A seller may mark a listing sold for inventory organization,
but that state alone never proves payment, fulfillment, receipt issuance, or a
completed HDC marketplace transaction.

---

## ADR-008

Payment-Neutral Purchase Requests and Browser Origin Policy

Status: Accepted

Reason:
Until a payment and fulfillment provider is activated, HDC records a buyer's
request, a seller's decision, and atomic inventory allocation without calling
the result a paid or completed sale. Submitted requests do not reserve stock;
acceptance rechecks active inventory and allocates it in one database
transaction. Participant dashboards are account-scoped and public catalog
responses never expose participant account UUIDs.

Flutter web access uses an origin allow-list rather than wildcard CORS. The API
permits its own origin, explicitly configured hosted frontend origins, and
narrow loopback origins for local Chrome development. This keeps browser
authentication portable while preventing arbitrary websites from reading HDC
API responses.
