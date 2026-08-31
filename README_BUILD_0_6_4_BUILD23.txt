HDC 0.6.4+23 - RESPONSIVE INTERFACE FOUNDATION
================================================

PURPOSE
- Give HelpDesk Connect one distinctive, consistent interface across startup,
  account entry, onboarding, navigation, and the main workspace.
- Make the highest-use HDC actions easier to find on both desktop and mobile.
- Preserve the complete Build 22.1 data, authorization, and audit baseline.

DELIVERED
- Shared HDC color, spacing, typography, brand, card, button, field, header,
  section-title, status-badge, and responsive-shell components.
- Responsive sign-in and registration with unchanged recovery questions,
  Terms and Privacy acceptance, legal-document access, and guest entry.
- Responsive dashboard navigation with direct access to requests, offers,
  active services, technician jobs, products, profiles, roles, notifications,
  HDC Passport, and authorized private operations.
- Redesigned dashboard signal header and primary workflow actions.
- Redesigned platform onboarding, Flutter splash, and pre-Flutter recovery UI.

UNCHANGED SAFETY BOUNDARIES
- The API and PostgreSQL remain authoritative for accounts and workflows.
- Only explicit local-provider configuration may use device-local workflow
  storage; unknown provider values continue to fail closed.
- Accepted-service records, chat, payments, documents, disputes, and audit
  evidence retain their Build 22.1 participant and staff authorization rules.
- HDC still records external-payment evidence only and does not process funds.
- No database migration is included in Build 23.

REQUIRED RELEASE CHECKS
1. Run Flutter analysis and all Flutter widget/unit tests.
2. Run migration checksum, portability, release-sync, type, API, workflow,
   authorization, concurrency, backup, and recovery tests.
3. Build the production Flutter web bundle and verify synchronized Build 23
   startup, dashboard, API health, and generated-bundle markers.
4. Verify authentication entry, Customer dashboard, Technician navigation, and
   responsive layout before production promotion.

LIVE ACCEPTANCE CHECK
1. Sign in as Customer and confirm requests, offers, and active services open.
2. Sign in as Technician and confirm Technician Jobs and active services open.
3. Confirm recovery, Terms, Privacy, guest access, and sign-out remain usable.
4. Confirm notification badges and dashboard counts match provider data.
5. Confirm chat and the transaction toolbox retain participant-only access.
