# Build 27 — Operations reports and profile clarity

## Owner workflow

Every Operations snapshot now opens a searchable, paginated report. Snapshot
records uses the same status definition as its counter. All records includes
history within the viewer's authorized scope. Selecting a record opens its
individual details; detail requests do not lose a record when its status changes.

| Snapshot | Individual details |
| --- | --- |
| My assignments / Staff assignments | Member, department, section, title and assigner |
| Active departments | Code, description, status and creator |
| Active sections | Department, code, description, status and creator |
| Active accounts | Member ID, name, registration/status, email verification, profile and active roles |
| Pending applications | Applicant, requested role, answers, notes and review decision |
| Recovery reviews | Member, delivery status, reviewer and decision; no security answers or fingerprints |
| Pending disputes | Participants, case summary, requested outcome, resolution, evidence and case history |
| Open service requests | Customer, requirements, location, schedule, budget and offers |
| Active transactions | Participants, accepted terms, progression and recorded activity |
| Guides for review / Published guides | Creator, latest review submitter, publisher, working/published content and version history |

“Active accounts” means enabled registered accounts, not online presence. Account
names are displayed with stable member IDs to distinguish members with the same
display name. HDC currently has display names rather than a separate username field.

Knowledge Base activity also appears directly on the private operations page.
Attribution comes from existing article/version actor IDs. The publisher remains
the actor of the published version while a newer review is edited. Legacy records
without a retained actor display “Not recorded.” Public Knowledge Base responses
are unchanged.

## Access and bounded reads

The API rechecks the current session and active internal roles. Owner/Super Admin
can read all reports. Admin retains operational-resource access but cannot read
dispute or organization reports. Delegated application reviewers remain limited
to their assigned role scope. My assignments remains tied to the current user.

Report lists default to 25 records, capped at 100, with total counts and navigation.
Detail history/evidence pages contain 25 records with explicit continuation.
Search terms and identifiers are bound SQL values. Lists contain summaries;
full data is returned for individual authorized records. Responses use no-store.
The UI clears reports after an account/role change or rejected refresh.

## Profiles

- Member summaries show introduction, location and preferred contact.
- Completion lists missing essentials and treats a photo as optional.
- Each role profile has clear public/private visibility and a preview containing
  only role-profile fields, separate from sign-in email and recovery information.
- Responsive actions wrap on compact screens.
- Profile responses are checked for the current account and requested role.
  Duplicate saves and late responses after account changes are rejected.

## Validation and release

This change uses existing tables and actor history; no migration or dependency
change is required. Verification covers API permissions/input bounds, PostgreSQL
report execution and pagination, publication attribution, dispute evidence/history,
live-role revocation, account-switch handling and compact report/preview layouts.
Flutter analysis/build and the existing clean PostgreSQL backup/restore gate remain
required CI checks. A review preview is not a production promotion.

Shop Technology preparation is recorded in `docs/build28-shop-technology.md`.
