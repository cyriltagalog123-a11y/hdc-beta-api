# HDC Social Bridge — Build 0.1

Private Facebook Page publishing bridge for HelpDesk Connect.

## What Build 0.1 does

- Connects a Facebook account through Meta OAuth.
- Requests `pages_show_list`, `pages_read_engagement`, and `pages_manage_posts`.
- Discovers Pages that the authorized Facebook account can manage.
- Encrypts Page access tokens before storage.
- Publishes text-only Facebook Page posts from an owner-only dashboard.
- Exposes a protected MCP endpoint for ChatGPT/custom MCP clients.
- Provides MCP tools to list connected Pages, list recent Page posts, and publish a text post.
- Requires `confirm=true` for the MCP publishing tool.
- Records connection and publishing actions in an audit log.
- Does not contain ad/boost actions.

## Important Meta requirement

This bridge uses Meta's official Pages API. Meta controls which permissions are granted to the app. During development, the app may work only for Meta app roles/testers. Wider production use can require Meta App Review and/or business verification depending on Meta's current requirements.

## Security model

- Facebook passwords are never stored by HDC Social Bridge.
- Meta tokens are encrypted with AES-256-GCM before database storage.
- Owner dashboard uses HTTP Basic authentication.
- MCP endpoint uses a separate Bearer API key.
- OAuth callback uses a signed, expiring state value.
- Publishing actions are audit logged.

## Required environment variables

Copy `.env.example` into your hosting provider's environment settings and fill in real values there. Do not commit secrets.

For production deployment, configure `DATABASE_URL`. Without it, Build 0.1 uses in-memory storage and all Facebook connections disappear whenever the process restarts.

## Meta Developer setup

1. Create a Meta app intended to manage the HDC Facebook Page.
2. Add Facebook Login / the appropriate Facebook authentication product offered by the current Meta developer dashboard.
3. Set the OAuth redirect URL to:

   `https://YOUR-SOCIAL-BRIDGE-DOMAIN/auth/facebook/callback`

4. Put the Meta App ID and App Secret into deployment environment variables.
5. Set `META_GRAPH_VERSION` to the version supported by the Meta app at setup time.
6. Keep the app limited to owner/developer/tester use until Meta's production permission requirements are satisfied.

## MCP connection

Endpoint:

`https://YOUR-SOCIAL-BRIDGE-DOMAIN/mcp`

Authentication:

`Authorization: Bearer <SOCIAL_BRIDGE_API_KEY>`

Available Build 0.1 tools:

- `list_connected_pages`
- `list_recent_posts`
- `publish_text_post`

The publishing tool requires `confirm=true` and its description instructs the client to call it only after explicit user approval of the exact post.

## Local testing

Use Node.js 20 or newer. Install dependencies, configure environment variables, and start the server. Open `/admin`, connect Facebook, then run one controlled text-post test.

## Build 0.2 candidates

After text publishing works end-to-end:

- single-image posts
- link posts
- scheduling queue
- comments/replies
- Page analytics
- token health checks and reconnect reminders
- owner approval queue
