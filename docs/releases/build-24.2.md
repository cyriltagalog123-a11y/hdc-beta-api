# HDC Build 24.2 — Controlled Locations and Platform Role Administration

Build 24.2 closes the pre-Build-25 location and role-administration requirements.

## Included

- Registration location uses a controlled Philippines Region → Province/Independent City selection.
- Role applications use controlled location/work-premises selections rather than arbitrary typed locations.
- Member profiles, platform-role profiles, and service requests use the same controlled location catalog.
- Backend and database constraints reject unsupported new/updated location values.
- Owner, Super Admin, and approved Admin accounts can assign or revoke Technician, Seller, Business, Supplier, and Store roles.
- Customer remains the non-removable baseline platform role.
- Manual role changes require a reason, create an audit event, and notify the affected member.
- Controlled-location migrations use versions 0017 and 0018 to preserve the existing migration order.
- The existing Build 24A service-request selector remains stable for regression coverage, while PostgreSQL integration fixtures now use the same canonical location format enforced in production.

## Release gate

Merge/deploy only after portability, migration checksum, release synchronization, TypeScript tests, Flutter analyze/test/build, PostgreSQL integration, and backup/restore rehearsal are green.
