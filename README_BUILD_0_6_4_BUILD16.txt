HDC 0.6.4+16 - SECURE NETLIFY WEB AND API DEPLOYMENT FOUNDATION
================================================================

PURPOSE
- Serve Flutter web, password recovery, and the HDC API from one HTTPS origin.
- Keep the beta deployment at zero direct cost while preserving a clean path
  to another host, database, custom domain, or paid provider later.

IMPLEMENTED
- Netlify publishes the compiled Flutter application from build/web while
  retaining in-code /api/* Function routes.
- Flutter web resolves the API from its own trusted origin; native clients keep
  the existing public HTTPS API default.
- Pinned Flutter 3.47.1 build script enforces pubspec.lock, then runs analyzer,
  tests, and release compilation before packaging the password-reset page.
- Static and API responses receive restrictive framing, MIME, referrer,
  permission, caching, and content-security policies.
- Added a provider-neutral deployment, preview, promotion, rollback, and secret
  scoping runbook.
- Rehearsed migrations 0006, 0007, and 0008 on isolated Neon branch
  br-quiet-lab-ax2t8md3. Versions 0001-0008, required relations, RLS, eight
  required triggers, and two distinct existing account UUIDs were verified.
- Applied that reviewed migration transaction to Neon main after explicit
  approval and retained pre-change rollback branch br-bitter-lake-ax1z58wp.

RELEASE GATES
1. Run npm ci and npm run verify.
2. Run the pinned Flutter build through npm run build:web.
3. Test the exact web/API release against an isolated Neon branch.
4. Obtain explicit approval before changing Neon main.
5. Apply the reviewed migration sequence, publish the matching Netlify release,
   and repeat health, CORS, login, account-isolation, and commerce smoke tests.

SECURITY LIMITS
- Do not give deploy previews a production database connection string.
- Do not place database URLs, session secrets, recovery peppers, or provider
  credentials in Flutter, netlify.toml, documentation, or source control.
- Current purchase acceptance allocates stock but does not prove payment,
  delivery, fulfillment, a receipt, or a completed sale.
