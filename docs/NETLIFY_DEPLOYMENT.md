# HDC Netlify Deployment

## Production topology

HDC uses one HTTPS origin for both the Flutter web client and the HDC API:

- `/` serves the compiled Flutter web application from `build/web`.
- `/reset-password/` serves the one-time password-reset page.
- `/api/*` is handled by the TypeScript Netlify Function.
- PostgreSQL credentials and signing secrets exist only in the Netlify
  Functions environment and are never compiled into Flutter.

The web build uses `HDC_API_BASE_URL=same-origin`. A custom domain can therefore
replace the Netlify hostname without rebuilding the client or widening CORS.
Separate hosted frontends remain denied unless their exact HTTPS origins are
added to `HDC_WEB_ALLOWED_ORIGINS`.

## Reproducible local build

Install the Flutter version recorded in `.flutter-version`, then run:

```bash
npm ci
npm run verify
HDC_FLUTTER_BIN=/absolute/path/to/flutter npm run build:web
```

The web build runs Flutter analysis and tests, creates a release bundle, and
copies the password-reset assets into `build/web`. Source maps are not emitted.
Deploy the generated directory and the matching `netlify/functions` source as
one atomic release.

## Required production secrets

Store these in Netlify, scoped to production Functions/runtime only:

- `HDC_DATABASE_URL` using Neon's pooled TLS connection string.
- `HDC_SESSION_SECRET` with at least 32 random characters.

Keep previous signing or recovery keys during a planned rotation. Optional
provider selectors and delivery credentials remain disabled until their
provider adapters are activated. Never put credentials in `netlify.toml`, a
Dart define, the web bundle, a log, or this document.

## Safe promotion order

1. Create a Neon branch from production.
2. Apply pending migrations in numeric order and verify the ledger, RLS,
   triggers, constraints, and account UUID isolation.
3. Build and test the exact web/API release locally.
4. Deploy a Netlify preview using the Neon branch and preview-only secrets.
5. Test health/readiness, CORS preflight, login, logout, account isolation,
   catalog browsing, buyer requests, seller decisions, and stock allocation.
6. Obtain explicit production approval.
7. Apply the same reviewed migrations to Neon `main`.
8. Publish the matching Netlify release and repeat the smoke tests.

Deploy previews must never receive the production database connection string.
If a safe preview database is not configured, the preview API should fail
closed rather than use production data.

## Rollback

- Keep the prior successful Netlify deploy available for instant site rollback.
- Before important database changes, create a current Neon branch/checkpoint.
- If deployment validation fails before new writes depend on the schema, roll
  back the Netlify deploy and investigate on an isolated branch.
- Do not reverse a live database migration blindly after marketplace writes.
  Preserve evidence, assess dependencies, and use a reviewed forward fix or
  Neon restore branch.

## Provider portability

Netlify and Neon are current adapters, not HDC identity authorities. HDC UUIDs,
public references, audit records, and provider-neutral contracts remain stable
if hosting or PostgreSQL providers change. The cutover procedure is maintained
in `docs/PORTABILITY_AND_RECOVERY.md`.
