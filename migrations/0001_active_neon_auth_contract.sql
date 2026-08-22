-- HDC active Neon authentication contract compatibility
--
-- The active HDC authentication bootstrap stores platform roles as constrained
-- text. Later domain migrations use the provider-neutral hdc_account_role enum.
-- This migration validates the existing values and performs that one safe,
-- lossless conversion. It intentionally does not apply the historical
-- Supabase auth migration in backend/supabase/migrations.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_users') IS NULL THEN
    RAISE EXCEPTION 'HDC auth prerequisite public.hdc_users is missing';
  END IF;

  IF to_regclass('public.hdc_user_roles') IS NULL THEN
    RAISE EXCEPTION 'HDC auth prerequisite public.hdc_user_roles is missing';
  END IF;
END
$$;

DO $$
BEGIN
  IF to_regtype('public.hdc_account_role') IS NULL THEN
    CREATE TYPE public.hdc_account_role AS ENUM (
      'customer',
      'technician',
      'seller',
      'business',
      'store',
      'admin',
      'super_admin',
      'supplier'
    );
  END IF;
END
$$;

DO $$
DECLARE
  missing_role_values text;
BEGIN
  SELECT string_agg(required_role, ', ' ORDER BY required_role)
  INTO missing_role_values
  FROM unnest(ARRAY[
    'customer',
    'technician',
    'seller',
    'business',
    'store',
    'admin',
    'super_admin'
  ]) AS required_role
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_type role_type
    JOIN pg_enum role_value ON role_value.enumtypid = role_type.oid
    JOIN pg_namespace role_namespace
      ON role_namespace.oid = role_type.typnamespace
    WHERE role_namespace.nspname = 'public'
      AND role_type.typname = 'hdc_account_role'
      AND role_value.enumlabel = required_role
  );

  IF missing_role_values IS NOT NULL THEN
    RAISE EXCEPTION
      'public.hdc_account_role is missing required values: %',
      missing_role_values;
  END IF;
END
$$;

DO $$
DECLARE
  unsupported_roles text;
BEGIN
  SELECT string_agg(role_value, ', ' ORDER BY role_value)
  INTO unsupported_roles
  FROM (
    SELECT DISTINCT role::text AS role_value
    FROM public.hdc_user_roles
    WHERE role::text NOT IN (
      'customer',
      'technician',
      'seller',
      'business',
      'store',
      'admin',
      'super_admin',
      'supplier'
    )
  ) invalid_roles;

  IF unsupported_roles IS NOT NULL THEN
    RAISE EXCEPTION
      'Unsupported values exist in public.hdc_user_roles.role: %',
      unsupported_roles;
  END IF;
END
$$;

-- The active auth bootstrap check excludes later platform roles such as store
-- and supplier. The enum plus migration 0003's platform-only constraint replace
-- it with the complete domain contract.
ALTER TABLE public.hdc_user_roles
  DROP CONSTRAINT IF EXISTS hdc_user_roles_role_check;

DO $$
DECLARE
  current_role_type text;
BEGIN
  SELECT format('%I.%I', column_type_namespace.nspname, column_type.typname)
  INTO current_role_type
  FROM pg_attribute role_column
  JOIN pg_class role_table ON role_table.oid = role_column.attrelid
  JOIN pg_namespace table_namespace
    ON table_namespace.oid = role_table.relnamespace
  JOIN pg_type column_type ON column_type.oid = role_column.atttypid
  JOIN pg_namespace column_type_namespace
    ON column_type_namespace.oid = column_type.typnamespace
  WHERE table_namespace.nspname = 'public'
    AND role_table.relname = 'hdc_user_roles'
    AND role_column.attname = 'role'
    AND role_column.attnum > 0
    AND NOT role_column.attisdropped;

  IF current_role_type IS NULL THEN
    RAISE EXCEPTION 'HDC auth prerequisite public.hdc_user_roles.role is missing';
  END IF;

  IF current_role_type <> 'public.hdc_account_role' THEN
    ALTER TABLE public.hdc_user_roles
      ALTER COLUMN role TYPE public.hdc_account_role
      USING role::text::public.hdc_account_role;
  END IF;
END
$$;

COMMIT;
