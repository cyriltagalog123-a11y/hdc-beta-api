# Build 24.1 — Live responsiveness tuning

This patch is intentionally limited to post-login synchronization behavior. It does not change login/authentication timing, transaction authority, database schemas, or workflow rules.

## Changes

- Refresh signed-in workflow state every 4 seconds while the Flutter app is in the foreground.
- Pause workflow polling outside the resumed app lifecycle and coalesce overlapping refreshes.
- Refresh cached backend-authoritative private conversations every 2 seconds after a conversation has been opened.
- Preserve incremental message cursors, idempotent sends, stale-snapshot protection, moderation, and account/participant authorization.

## Expected effect

- Cross-account transaction status changes should normally become visible within a few seconds rather than waiting for page re-entry or manual refresh.
- Incoming private chat messages should normally appear within about 2 seconds plus network latency instead of relying on the screen's 15-second fallback poll.

## Limit

This remains polling, not push-based realtime. WebSocket/SSE or provider realtime can be introduced later if HDC usage justifies persistent realtime infrastructure.
