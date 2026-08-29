HDC 0.6.4+22 - TRANSACTION RELIABILITY, PAYMENTS, DOCUMENTS, AND DISPUTES
=============================================================================

PURPOSE
- Make accepted-service coordination reliable and auditable for both parties.
- Record externally completed payments without claiming HDC processes money.
- Give Customers and Technicians a safe evidence and dispute workflow.

DELIVERED MILESTONES
- Build 20.1A: notification center, unread state, proposal/service alerts,
  idempotent chat sends, incremental sync, and foreground-aware polling.
- Build 20.1B: schedule proposals, Technician price change orders, participant
  decisions, cancellations, non-response reports, and no-show review records.
- Build 21: external-payment records, counterparty confirmation, refund
  records, and immutable receipts after both participants confirm payment.
- Build 22: structured-text documents with SHA-256 digests, participant-opened
  disputes, automatic action freezes, and Owner/Super Admin resolution.

SAFETY BOUNDARIES
- HDC does not collect, hold, route, or refund money in this release.
- Never enter card, bank, wallet, password, or one-time-code information into
  a payment reference, document, chat message, or dispute.
- Binary uploads are disabled until object storage, content scanning, retention,
  and deletion controls are available. Build 22 documents are text only.
- Opening a dispute freezes schedule, price, payment, refund, and exception
  changes until an authorized resolution is recorded.
- Only the service Customer and Technician can access transaction records under
  row-level security. Only Owner or Super Admin can resolve a dispute.

REQUIRED RELEASE ORDER
1. Rehearse migrations 0012 through 0015 on an isolated Neon branch.
2. Verify migration records, RLS policies, indexes, triggers, and idempotency.
3. Apply the identical migrations to production before deploying the API.
4. Deploy the synchronized Build 22 API and verified Flutter web bundle.
5. Smoke-test health/readiness and the public startup/login experience.

LIVE ACCEPTANCE TEST
1. As Customer, open an accepted service and propose a schedule change.
2. As Technician, accept it and propose a price change; as Customer, approve it.
3. Record an external payment as Customer, confirm it as Technician, then
   confirm receipt as Customer and verify the immutable receipt appears.
4. Add a structured-text document and verify it appears for both participants.
5. Open a dispute and verify schedule, price, and payment actions are frozen.
6. As Owner or Super Admin, resolve the dispute and confirm the event appears
   in both participants' transaction history.
7. Send chat messages from both accounts and confirm incremental sync, unread
   notifications, and retry behavior do not create duplicate messages.

SYNCING VS CODE / WINDOWS
1. Pull the Build 22 main branch into a clean project folder.
2. Stop the existing Flutter process and run `flutter clean`.
3. Run `flutter pub get --enforce-lockfile`.
4. Run `flutter run -d windows` or select Chrome.
5. Confirm the footer says Build 22 and `/api/health` reports
   `0.6.4-build22`.
