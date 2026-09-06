# HDC Build 25 — Distinctive Interface Redesign

Build 25 is the deferred application-wide visual and interaction redesign that begins only after the beta-critical workflow baseline is complete. It must preserve all provider authority, role boundaries, transaction records, security controls, database contracts, and responsive behavior delivered through Build 24.2.

## Sequence

### Build 25A — Visual system foundation

- Strengthen HDC's technical identity through shared colors, surfaces, hierarchy, focus states, cards, buttons, fields, and signal treatments.
- Keep the approved HDC logo and existing accessibility contrast requirements.
- Make shared components carry the visual redesign so feature screens do not fork their own style systems.

Status: implementation complete; full validation passed.

### Build 25B — Authentication and onboarding

- Redesign sign-in, registration, guest preview entry, recovery, legal acceptance, and onboarding presentation without weakening authentication or legal gates.
- Preserve controlled-location registration, recovery questions, backend-authoritative sessions, and Customer baseline account creation.

Status: implementation complete; full validation passed after updating the stale Build 24 release-identity regression.

### Build 25C — Application shell and navigation

- Redesign sidebar/drawer/app-bar navigation with clearer workspace identity, account context, notifications, badges, and responsive behavior.
- Preserve role-authorized destinations and fail-closed route behavior.

Status: implementation complete; full validation passed.

### Build 25D — Dashboards and workspace priorities

- Improve Customer, Technician, Seller/Business, combined-role, and internal dashboard hierarchy around current work, required action, recent activity, and role switching.
- Do not synthesize counts or data that providers did not return.

Status: implementation complete; full validation passed. The old hard-coded `RECORD SYNC ON` display was removed because it did not represent provider-backed state.

### Build 25E — Service workflow visual integration

- Apply one consistent HDC workflow language across service requests, technician discovery, offers, acceptance, active services, chat, payments, documents, and disputes.
- Preserve every Build 24 workflow rule, participant check, freeze rule, idempotency rule, and authoritative transition.

Status: implementation complete; full validation passed.

### Build 25F — Profiles, commerce, and internal tools

- Apply the shared design system to member/role profiles, role applications, commerce/catalog/sales surfaces, notifications, security, and internal administration.
- Preserve public/private profile boundaries, platform-role authority, audit reasons, and commerce recording rules.

Status: implementation complete; full validation passed after removing obsolete interface helpers found by Flutter analysis. Profile/workspace identity, account security, marketplace purchase-request framing, provider-backed notification state, and private operations all use the shared Build 25 presentation while preserving their authority boundaries.

### Build 25G — Accessibility, performance, and final regression

- Verify keyboard/focus navigation, semantics, compact-screen reachability, text scaling resilience, loading/error/empty states, and reduced accidental actions.
- Run Flutter analysis/tests/build, API tests, PostgreSQL workflow/isolation coverage, migration/release checks, encrypted backup/restore rehearsal, and Netlify deploy-preview validation.
- Build 25 may be merged to `main` or deployed to production only after explicit approval.

Status: complete. Release identity is synchronized to Build 25 across package, Flutter, API health, startup, dashboard, CI, and the generated web bundle. Final regression coverage verifies semantic/responsive shared UI, provider-backed state, authority wording, and absence of temporary Build 25 repair machinery. HDC CI run `34029218139` passed core verification, Flutter analyze/tests/build, PostgreSQL workflow/isolation, and encrypted backup/restore; the Netlify PR #19 deploy preview also passed.

## Completion rule

Sub-builds are completed in order. A failing gate is fixed before the next sub-build advances. The final Build 25 review branch must contain no temporary repair workflow or helper artifact.
