HDC 0.6.4+24 - BUILD 24A CUSTOMER REQUEST AND TECHNICIAN DISCOVERY REDESIGN
============================================================================

PURPOSE
- Carry the Build 23 responsive HDC interface into the Customer request and
  Technician discovery workflows.
- Make request progress, offers, and accepted work easier to understand on
  desktop and mobile.
- Preserve the complete Build 22.1 data, authorization, audit, and recovery
  baseline.

DELIVERED
- Shared guided-flow, metric, responsive-action, section, and empty-state UI
  primitives.
- A describe-review-publish Customer request flow with unchanged validation,
  account gates, retry-safe request references, editing, and publication.
- A newest-first My Service Requests center with All, Active, With offers, and
  Closed filters backed by the authenticated request and proposal providers.
- A responsive request record with visible offer counts, proposal access,
  activity, Nexus insight, cancellation, and accepted-service workspace access.
- A responsive Technician directory with manual skill/specialty/name search,
  textual service-area prioritization, public contact details, and profile
  privacy guidance.
- Responsive widget tests plus static Build 24A workflow-contract tests.

TRUTHFUL DISCOVERY BOUNDARY
- Only active, approved Technician profiles whose owners enabled public
  discovery are returned by the authenticated directory endpoint.
- Public profile fields remain technician-supplied. Stated experience, radius,
  rate, availability, location, skills, and specialties are labeled as such.
- Build 24A does not manufacture ratings, job counts, exact GPS distance, or
  private account data.

UNCHANGED SAFETY BOUNDARIES
- The API and PostgreSQL remain authoritative for accounts and workflows.
- Request, proposal, transaction, chat, payment, document, and dispute access
  retain their existing participant and staff authorization rules.
- No database migration, API route, provider selection, or production data
  change is included in Build 24A.
- HDC still records external-payment evidence only and does not process funds.

REQUIRED RELEASE CHECKS
1. Run Flutter formatting, analysis, unit tests, and responsive widget tests.
2. Run migration checksum, portability, release-sync, type, API, workflow,
   authorization, concurrency, backup, and recovery tests.
3. Build the Flutter web bundle and verify synchronized numeric Build 24
   startup, dashboard, API health, artifact, and generated-bundle markers.
4. Review the Customer request flow at compact and desktop widths.
5. Confirm Technician discovery shows only public provider-backed records and
   retains its sign-in and profile-visibility boundaries.

LIVE ACCEPTANCE CHECK
1. As Customer, create, review, and publish a request; confirm it appears in My
   Service Requests with the same request reference.
2. Confirm All, Active, With offers, and Closed filters show the correct
   account-owned records and every offer remains accessible.
3. Accept an offer and confirm Open Workspace reaches the active service.
4. Search Technician profiles by skill and area; confirm map and public contact
   actions reflect only the published profile fields.
5. Repeat the main flow on a compact screen and confirm actions stack without
   horizontal overflow.
