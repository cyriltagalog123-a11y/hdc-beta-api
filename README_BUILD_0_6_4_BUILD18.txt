HDC 0.6.4+18 - LIVE TECHNICIAN REQUEST DISCOVERY
================================================

PURPOSE
- Make a newly posted service request appear for another signed-in Technician
  without requiring that Technician to sign out and back in.
- Keep customer-owned requests and technician opportunities correctly scoped.
- Keep the Flutter source, hosted web client, and API release visibly aligned.

IMPLEMENTED
- Technician Marketplace refreshes on entry, pull-to-refresh, and its refresh
  button. It shows a last-updated time and a recoverable connection error.
- Search covers title, category, description, customer, and service location.
- Nearby-area sorting compares the textual service area saved in the
  Technician profile. Newest and urgency sorting remain selectable.
- Requests from the same account are omitted from its Technician feed, My
  Service Requests is customer-ID filtered, and the API rejects self-proposals.
- A Map action opens the request's textual service area using a replaceable URL
  template. OpenStreetMap is the zero-cost default and no map key is stored.
- A release check prevents package, Flutter, dashboard, and API build markers
  from drifting apart again.

LOCATION LIMIT
- Build 18 does not calculate exact kilometers or expose a live home address.
  HDC currently stores location text only. Exact nearest-tech matching should
  be added later with consented coordinates, a public-area privacy policy, a
  service radius, and server-side geospatial queries.

SYNCING VS CODE / WINDOWS
1. Open this Build 18 project folder, or pull the Build 18 main-branch commit.
   Running an older extracted Build 16 folder will continue to display Build 16.
2. Stop the existing Flutter process.
3. Run `flutter clean`.
4. Run `flutter pub get --enforce-lockfile`.
5. Run `flutter run -d windows` (or select Chrome).
6. Confirm the dashboard footer says Build 18 and `/api/health` reports
   `0.6.4-build18`.

LIVE TEST
1. Sign in as Cyril and publish a request.
2. Keep Jon signed in, open Technician Marketplace, and pull down or press
   Refresh.
3. Search for the request title, category, or Cebu City.
4. Set Jon's Technician profile service area to Cebu City to test area ordering.
5. Open Map to verify the textual area lookup, then open the opportunity and
   prepare an offer.
