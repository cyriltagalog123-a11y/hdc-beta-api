HDC Sprint 6.4 — Appwrite Dependency + Stale Supabase Auth Fix

WHY THE 15 ANALYZER ISSUES APPEARED
1. Appwrite was added to pubspec.yaml, but Flutter had not resolved/downloaded
   the new package before flutter analyze was run. Until `flutter pub get`
   succeeds, every `package:appwrite/...` import is reported as missing.
2. The previous full HDC project still contained
   lib/core/auth/supabase_auth_gateway.dart. Flutter analyzes Dart files even
   when they are no longer imported, so its old `supabase_flutter` import
   continued producing an analyzer issue.

INSTALL / MERGE
Extract this patch into the ROOT of the full HDC Flutter project and overwrite
matching files. In particular, allow the included
lib/core/auth/supabase_auth_gateway.dart compatibility placeholder to replace
the old Supabase-auth implementation.

IMPORTANT — RUN IN THIS EXACT ORDER
From the HDC project root:

  flutter clean
  flutter pub get
  flutter analyze

Do not run `flutter analyze` before `flutter pub get` after changing pubspec.yaml.

If `flutter pub get` fails, STOP there and send the complete `flutter pub get`
error. Appwrite imports cannot resolve until package resolution succeeds.

AFTER ANALYZE IS CLEAN
Run Windows with the Appwrite project ID:

  flutter run -d windows --dart-define=HDC_APPWRITE_PROJECT_ID=YOUR_PROJECT_ID

SECURITY / ARCHITECTURE
- No Appwrite server API key belongs in Flutter.
- Only Project ID and endpoint are client configuration.
- HDC AuthGateway remains provider-neutral.
- Supabase/PostgreSQL remains a data backend candidate and Neon remains the
  PostgreSQL fallback; this patch removes only Supabase Auth from the client.
