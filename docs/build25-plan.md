# HDC Build 25 — Distinctive Interface Redesign

Build 25 is the deferred application-wide visual and interaction redesign that begins only after the beta-critical workflow baseline is complete. It must preserve all provider authority, role boundaries, transaction records, security controls, database contracts, and responsive behavior delivered through Build 24.2.

## Sequence

### Build 25A — Visual system foundation

- Strengthen HDC's technical identity through shared colors, surfaces, hierarchy, focus states, cards, buttons, fields, and signal treatments.
- Keep the approved HDC logo and existing accessibility contrast requirements.
- Make shared components carry the visual redesign so feature screens do not fork their own style systems.

Status: implementation complete; full PR validation passed before 25B began.

### Build 25B — Authentication and onboarding

- Redesign sign-in, registration, guest preview entry, recovery, legal acceptance, and onboarding presentation without weakening authentication or legal gates.
- Preserve controlled-location registration, recovery questions, backend-authoritative sessions, and Customer baseline account creation.

Status: implementation complete; awaiting owner-authored full CI validation before 25C begins.

### Build 25C — Application shell and navigation

- Redesign sidebar/drawer/app-bar navigation with clearer workspace identity, account context, notifications, badges, and responsive behavior.
- Preserve role-authorized destinations and fail-closed route behavior.

### Build 25D — Dashboards and workspace priorities

- Improve Customer, Technician, Seller/Business, combined-role, and internal dashboard hierarchy around current work, required action, recent activity, and role switching.
- Do not synthesize counts or data that providers did not return.

### Build 25E — Service workflow visual integration

- Apply one consistent HDC workflow language across service requests, technician discovery, offers, acceptance, active services, chat, payments, documents, and disputes.
- Preserve every Build 24 workflow rule, participant check, freeze rule, idempotency rule, and authoritative transition.

### Build 25F — Profiles, commerce, and internal tools

- Apply the shared design system to member/role profiles, role applications, commerce/catalog/sales surfaces, notifications, security, and internal administration.
- Preserve public/private profile boundaries, platform-role authority, audit reasons, and commerce recording rules.

### Build 25G — Accessibility, performance, and final regression

- Verify keyboard/focus navigation, semantics, compact-screen reachability, text scaling resilience, loading/error/empty states, and reduced accidental actions.
- Run Flutter analysis/tests/build, API tests, PostgreSQL workflow/isolation coverage, migration/release checks, encrypted backup/restore rehearsal, and Netlify deploy-preview validation.
- Build 25 may be merged to `main` or deployed to production only after explicit approval.

## Completion rule

Sub-builds are completed in order. A failing gate is fixed before the next sub-build advances. The final Build 25 review branch must contain no temporary repair workflow or helper artifact.
