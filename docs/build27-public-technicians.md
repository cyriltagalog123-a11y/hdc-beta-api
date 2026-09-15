# Build 27: public technician profiles

Status: review branch; production promotion is pending the release gates.
Date: 2026-09-15.

Approved, active technicians appear in search as soon as their role is granted.
The existing approval trigger creates the profile, so this no longer depends on
an extra profile visit or a discoverability switch. Guests can search and open
the same public profiles as signed-in members. Creating requests and all private
workspaces still require the existing authenticated account permissions.

| Profile data | Public behavior |
| --- | --- |
| Technician public name and member reference | Always shown while approved and active |
| Member profile photo | Shown when a valid HTTPS image is supplied; unavailable images have a fallback |
| Years of experience | Stated value from the technician profile; missing experience is labeled as missing |
| Ratings and reviews | Real active customer ratings for completed services delivered by this technician |
| Completed services | Count of recorded completed services delivered by this technician |
| Headline, description, service area, email, phone, website | Shown only when the technician selects each field |
| Skills, specialties, radius, hourly rate, availability, emergency service | Shown only when individually selected |
| Sign-in email, private member location/bio, account IDs, application answers, transaction IDs | Excluded from the public response |

Technicians use Profile Center → Technician → Edit profile to choose public
fields and save. Preview opens the same server projection used by visitors.
The profile photo is edited in the shared member profile. Optional sharing starts
empty for existing profiles as well: the legacy `is_public` value is not treated
as consent to reveal contacts or other details to guests. Private stored values
are retained when a field is hidden.

Server reads select active accounts with an active, approved technician role.
Role suspension/revocation, deactivation, or a disabled/locked account removes
both search and direct profile access.
Eligibility, selected fields, reputation totals and a page of reviews come from
one database statement. Reviews are ordered by creation time and ID, limited to
20 per page, and exclude withdrawn ratings and ratings received as a customer or
commerce participant. Public review responses contain no rater account ID or
private transaction reference. Search and detail refreshes discard unavailable
data; editor forms stop displaying or saving a previous account's role profile.

HTTPS profile images use Flutter's HTML image strategy on web, allowing image
hosts without CORS support. CSP permits HTTPS images while API connections stay
same-origin; the site sends no referrer. Avatar updates reject non-HTTPS URLs and
URLs containing credentials. Review entry explains where service feedback is
published.

No migrations, production dependency changes, production secrets, shop
implementation, release version bump, or generated bundles are included. The
existing `details` JSON stores the allow-listed field preferences. The Build 27
label remains current.

The final dependency review identified the development-only Vitest advisory
[GHSA-82fw-gwwq-j7x9](https://github.com/vitest-dev/vitest/security/advisories/GHSA-82fw-gwwq-j7x9).
Vitest is pinned to patched version `4.1.11`; CI now audits both production and
test dependencies and rejects moderate or higher advisories. The complete
existing test suites run on the updated tool before release.

## Validation and release gates

- Local repository verification: migration checksums, portability, release identity,
  TypeScript and 186 runnable tests; dependency audit reports no vulnerabilities.
- PostgreSQL CI: real role application/approval without a profile visit, guest
  projection, hidden-field preservation, edits limited to the profile owner, suspension/deactivation,
  review totals/pagination, customer reputation separation and withdrawal.
- Flutter CI: guest search → profile at 320px and 1200px, refresh after revocation,
  visibility save and account-change guard, plus existing analysis/tests/web build.
- Full CI also runs clean migration/upgrade rehearsal and encrypted backup/restore.
- Production release follows the repository policy: successful review checks,
  production backup, rollback branch, approved merge, exact deploy identity and
  live readiness verification.
