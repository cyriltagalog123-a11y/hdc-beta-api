HDC Sprint 6.4 — Appwrite Session Timestamp Fix

INSTALL
1. Extract this patch into the HDC Flutter project root.
2. Replace/merge the included files.
3. Run:
   flutter analyze

EXPECTED
No Session.createdAt analyzer error.

Then run:
   flutter run -d windows --dart-define=HDC_APPWRITE_PROJECT_ID=YOUR_PROJECT_ID
