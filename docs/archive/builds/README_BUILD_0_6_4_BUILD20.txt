HDC 0.6.4+20 - WORKFLOW AND PRIVATE CHAT RELIABILITY
====================================================

PURPOSE
- Restore every Customer-owned request when My Service Requests opens.
- Make Technician proposal submission reliable and visibly report failures.
- Make accepted-transaction chat work across the Customer and Technician
  accounts instead of storing each side's history on one device only.

IMPLEMENTED
- My Service Requests, request details, and Customer proposal inbox refresh the
  complete authorized workflow and expose a manual refresh action.
- Proposal autosave and submit are serialized. Submission waits for the latest
  edit, errors are displayed, and exact retries are safe after a lost response.
- Transaction chat is stored through authenticated API routes backed by
  migration 0010. Only the transaction Customer and Technician can read or
  write it under PostgreSQL row-level security.
- Chat includes server-side moderation, warning acknowledgement, read state,
  a 5 MB per-conversation beta quota, manual refresh, 12-second polling, and
  cache clearing/late-response rejection when the signed-in account changes.
- User-owned Drive/folder storage and realtime push delivery are not claimed in
  this build. HDC-managed storage is the only enabled beta choice.

REQUIRED RELEASE ORDER
1. Rehearse migration 0010 on an isolated Neon branch.
2. Verify both participant accounts and a non-participant denial.
3. Apply the identical migration to production only after approval.
4. Deploy the synchronized Build 20 API and Flutter web bundle.

LIVE TEST
1. Sign in as Cyril and open My Service Requests. Confirm all three existing
   requests appear, not only the newest one.
2. Sign in as Jon, open Cyril's active request, complete the proposal, and tap
   Submit Proposal. Confirm the success dialog appears.
3. Sign back in as Cyril, open that request and Professional Service Proposals,
   then refresh. Confirm Jon's submitted proposal appears.
4. Accept the proposal to create the service workspace.
5. Send one message as Cyril, sign in as Jon, open the same transaction chat,
   refresh, reply, then return to Cyril and confirm the reply appears.
6. Confirm a third account cannot open either participant's conversation.

SYNCING VS CODE / WINDOWS
1. Pull the Build 20 main branch into a clean project folder.
2. Stop the existing Flutter process and run `flutter clean`.
3. Run `flutter pub get --enforce-lockfile`.
4. Run `flutter run -d windows` or select Chrome.
5. Confirm the footer says Build 20 and `/api/health` reports
   `0.6.4-build20`.
