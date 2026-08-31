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

## Current milestone — Build 23

Build 23 is the HDC interface foundation. It delivers one responsive visual
system for startup, sign-in, registration, onboarding, navigation, and the
dashboard without changing database schemas or workflow authority.

Acceptance gates:

1. Authentication, recovery, legal acceptance, and guest entry remain intact.
2. Customer and Technician workflows remain reachable on desktop and mobile.
3. Offers, active services, notifications, and account context display the
   same provider-backed counts used before the redesign.
4. Flutter analysis/tests, API tests, release synchronization, and the web
   production build pass before deployment.

## After Build 23

Continue the design-system migration through the deeper service-request,
proposal, transaction, chat, payment, document, dispute, profile, role, and
marketplace screens in bounded releases. Each release must preserve the Build
22.1 data-security baseline and ship only after its workflow regression suite
passes.
