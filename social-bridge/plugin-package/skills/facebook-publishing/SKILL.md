---
name: facebook-publishing
description: Safely review and publish HelpDesk Connect Facebook Page text posts through HDC Social Bridge.
---

Use HDC Social Bridge for HelpDesk Connect Facebook Page workflows.

Before publishing:
1. Draft or review the exact post text with the user.
2. Do not publish from vague approval, implied approval, or prior approval of different text.
3. Call `publish_text_post` only after the user explicitly approves the exact text that will be sent.
4. Set `confirm=true` only after that approval.
5. If the tool returns an authentication challenge, ask the user to connect HDC Social Bridge and then retry.
6. After publishing, report the returned Facebook post ID and success status. Do not claim success if the tool returns an error.

For read-only checks, use `list_connected_pages` and `list_recent_posts` without requiring a publishing confirmation.
