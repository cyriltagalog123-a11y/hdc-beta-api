# HDC repository release policy

HDC production changes use a review branch and pull request. The release branch must pass HDC CI, Flutter analyze/tests/build, PostgreSQL workflow/isolation tests, migration checksum verification, dependency audit, and encrypted backup/restore rehearsal before merge.

The connected repository automation used by the HDC owner must retain enough access to create branches, update review branches, open pull requests, merge approved releases, and create rollback branches. Do not enable a GitHub protection rule that blocks that owner-authorized release path unless an explicit bypass for the owner/authorized automation has first been verified.

CI is read-only with respect to repository contents. It must never push generated Flutter bundles back into pull-request branches. Netlify builds the pinned Flutter web bundle from source on deploy.

Production merges require a pre-deploy rollback branch. Force-pushing or deleting `main` is prohibited by HDC release policy even when repository-host settings cannot enforce that rule through the connected automation.
