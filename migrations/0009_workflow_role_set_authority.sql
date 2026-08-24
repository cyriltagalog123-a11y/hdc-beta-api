-- HDC Build 17
-- Repair the PostgreSQL role-membership option required by the API to enter
-- the restricted hdc_app role before executing RLS-protected workflows.
-- Apply after migration 0008 on an isolated PostgreSQL branch first.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0008'
     )
     OR NOT EXISTS (
       SELECT 1 FROM pg_roles WHERE rolname = 'hdc_app'
     ) THEN
    RAISE EXCEPTION 'HDC migrations 0001 through 0008 must be applied first';
  END IF;
END
$$;

-- Neon/PostgreSQL role memberships can retain membership while explicitly
-- disabling SET ROLE. HDC deliberately executes user workflows as the
-- restricted NOLOGIN role so table RLS remains authoritative.
DO $$
BEGIN
  EXECUTE format(
    'GRANT hdc_app TO %I WITH SET TRUE',
    current_user
  );

  IF NOT pg_has_role(current_user, 'hdc_app', 'SET') THEN
    RAISE EXCEPTION 'HDC database owner cannot SET ROLE hdc_app';
  END IF;
END
$$;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES (
  '0009', 'workflow_role_set_authority', false
)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = false;

COMMIT;
