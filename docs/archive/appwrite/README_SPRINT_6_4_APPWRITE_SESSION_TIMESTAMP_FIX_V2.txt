HDC Sprint 6.4 — Appwrite Session Timestamp Fix v2

Correction:
The previous patch changed the wrong createdAt occurrence. The actual analyzer
error was this runtime Session field:

  final issuedAt = _parseDate(session.createdAt) ?? now;

It is now:

  final issuedAt = now;

Run:
  flutter analyze

Expected:
  The Session.createdAt error is gone.
