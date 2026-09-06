HDC 0.6.4+19 - LIVE TECHNICIAN DIRECTORY AND OPPORTUNITY FEED
==============================================================

PURPOSE
- Make open requests posted by one account reliably visible to a different
  signed-in account with an active Technician role.
- Let Customers search approved public Technician profiles manually and open
  their stated service area on a map.
- Preserve account, profile, and internal-role privacy while doing so.

IMPLEMENTED
- Technician Marketplace now reads a dedicated authenticated opportunity API
  instead of depending on the general workflow bootstrap cache.
- The opportunity API requires an active Technician role, returns only open or
  receiving-offers requests, and excludes requests posted by the same account.
- Find a Technician now searches public name, member ID, headline, description,
  skills, specialties, availability, and stated service area.
- Textual area matches are prioritized, and OpenStreetMap remains the no-key,
  replaceable map provider.
- Directory results contain a public member ID instead of the account UUID and
  never contain internal-role information.
- Discovery data and in-flight refreshes are isolated across account changes.

PRIVACY RULE
- Approval of a Technician role does not publish the profile automatically.
  The Technician must open Profiles & Workspaces, edit the Technician profile,
  and enable "Publicly discoverable profile". Only then can Customers find it.

LIVE TEST
1. Sign in as Jon and open Profiles & Workspaces > Technician.
2. Add a public name, skills, and service area, enable Publicly discoverable
   profile, then save.
3. From Jon's dashboard, use Browse Technician Jobs (engineering icon) or
   Technician Marketplace and refresh. Cyril's open request should appear.
4. Sign in as Cyril, open Find a Technician, and search for Jon, a saved skill,
   or the saved service area.
5. Open View service area to verify the map lookup. This is area-text search,
   not exact GPS distance or live-location tracking.

SYNCING VS CODE / WINDOWS
1. Pull the Build 19 main branch or extract this Build 19 package into a clean
   project folder. An older Build 16-18 folder will keep its older footer.
2. Stop the existing Flutter process.
3. Run `flutter clean`.
4. Run `flutter pub get --enforce-lockfile`.
5. Run `flutter run -d windows` or select Chrome.
6. Confirm the dashboard footer says Build 19 and `/api/health` reports
   `0.6.4-build19`.

LOCATION LIMIT
- HDC stores a user-entered service-area label, not a verified live coordinate.
  Exact nearest-Technician ranking should be added only with explicit location
  consent, a public-area privacy policy, radius controls, and server-side
  geospatial queries.
