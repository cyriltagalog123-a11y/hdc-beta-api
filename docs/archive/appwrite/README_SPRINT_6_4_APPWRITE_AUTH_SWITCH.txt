HDC Sprint 6.4 — Appwrite Authentication Switch

1. Merge this package into the latest HDC project.
2. Run flutter pub get.
3. Create/configure the free Appwrite project using APPWRITE_BETA_SETUP.txt.
4. Run:
   flutter analyze
   flutter run -d windows --dart-define=HDC_APPWRITE_PROJECT_ID=YOUR_PROJECT_ID
5. Create the two saved beta sample accounts from HDC's Create Account screen.
6. Test Guest -> Customer -> Technician -> Logout -> session restore.

The database/backend migration remains separate. Supabase PostgreSQL is not
being used as HDC's active authentication provider anymore.
