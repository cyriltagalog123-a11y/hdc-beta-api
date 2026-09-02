# HelpDesk Connect delivery roadmap

Last updated: 2026-08-31

## Delivered baseline

- Builds 12–19: provider-neutral accounts, role workspaces, profiles,
  marketplace foundations, service requests, and technician discovery.
- Build 20: authoritative cross-account requests, proposals, accepted services,
  and participant-only chat.
- Builds 20.1A–20.1B: notifications, incremental chat, schedules, price changes,
  and service exceptions.
- Builds 21–22: external-payment evidence, receipts, transaction documents, and
  disputes with authorized resolution.
- Build 22.1: database/legal hardening, fail-closed provider selection,
  transaction retention, required integration coverage, automated backups, and
  restore rehearsal support.

## Delivered responsive milestone — Build 24A

Build 24A migrates the Customer request and Technician discovery experience to
the responsive HDC interface foundation. It covers request intake, review,
Customer request records, request details, and the approved public Technician
directory without changing database schemas or workflow authority.

Acceptance gates:

1. Request validation, publication, editing, cancellation, and refresh retain
   their existing provider-backed behavior.
2. Every received offer remains reachable from both the Customer request list
   and request record; accepted work opens the existing service workspace.
3. Technician search lists only approved public profiles and never invents
   ratings, exact distances, or private account information.
4. Customer request and discovery layouts work without horizontal overflow on
   compact screens and use two-column working surfaces when space permits.
5. Flutter analysis/tests, API tests, release synchronization, and the web
   production build pass before deployment.

## Current milestone — Build 24B

Build 24B continues the same migration through Technician opportunities,
proposal creation, the Customer offer inbox, comparison, and acceptance. It
also adopts the approved blue HDC hexagon-and-H mark across the Flutter brand
lockup, startup shell, favicon, and installable web-app icons.

Acceptance gates:

1. Technician opportunity discovery remains provider-backed, account-scoped,
   filterable, and usable on compact and wide layouts.
2. A Technician can save and resume one draft, but cannot submit a second offer
   for the same issue after the first offer is recorded.
3. Every Customer offer remains reachable; shortlist, comparison, details, and
   acceptance retain the existing authoritative proposal workflow.
4. Comparison cards stack on compact screens instead of requiring horizontal
   page scrolling, and all offer/acceptance actions remain reachable.
5. The approved HDC logo is packaged locally with no remote-image dependency;
   maskable icons retain safe padding around the full hexagon.
6. Flutter analysis/tests, API tests, release synchronization, and the web
   production build pass before deployment.

Later bounded releases cover the service workspace, chat, payment evidence,
documents, disputes, profiles, roles, and commerce. Each release preserves the
Build 22.1 data-security baseline and ships only after its workflow regression
suite passes.
