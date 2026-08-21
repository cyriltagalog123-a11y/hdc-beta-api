# HDC Beta Auth API

Provider-neutral authentication API for HelpDesk Connect (HDC) beta clients.

## Architecture

HDC Flutter clients call this HTTPS API. The API owns authentication, session validation, role lookup, and security auditing. Neon PostgreSQL is currently the persistence provider and Netlify Functions is currently the hosting provider. Provider-specific details stay behind the backend boundary so Flutter never receives database credentials or direct database access.

## Endpoints

- `GET /api/health`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/session`
- `POST /api/auth/logout`

Public registration always creates the `customer` role only. Technician, seller, and business roles must be granted by trusted backend/admin workflows; client-supplied roles are never accepted as authorization.

## Required server environment variables

- `DATABASE_URL`
- `HDC_SESSION_SECRET`

Never commit real values. Store them in the hosting provider's secret/environment-variable system.

## Local checks

```bash
npm install
npm run typecheck
npm test
```

For local Netlify execution, use Netlify's development command with local environment variables kept outside source control.

## Security notes

- Passwords are hashed with bcrypt before persistence.
- Session tokens are signed server-side and are backed by revocable database sessions.
- Active roles are read from the backend when a session is checked rather than trusting role claims supplied by Flutter.
- Failed login attempts are rate-limited by a keyed identity fingerprint and recorded in the security audit log.
- API responses use generic errors and do not return database credentials or internal exception details.
- The repository intentionally contains no beta account passwords, database URLs, or session secrets.

## Current beta limitations

This is the initial authentication slice. Email verification, password recovery, stronger device/session controls, privileged-role provisioning, and broader platform authorization checks belong to later HDC backend work.
