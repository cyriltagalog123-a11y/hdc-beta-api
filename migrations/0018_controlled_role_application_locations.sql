-- HDC Build 24.2
-- Enforce controlled Philippines locations inside structured platform-role applications.
-- Existing legacy application rows remain untouched; inserts and relevant updates
-- are validated by a database trigger against the HDC catalog.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0017'
     ) THEN
    RAISE EXCEPTION 'HDC migration 0017 must be applied first';
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.hdc_is_supported_region(value text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
  SELECT value = ANY (ARRAY[
    'National Capital Region',
    'Cordillera Administrative Region',
    'Ilocos Region',
    'Cagayan Valley',
    'Central Luzon',
    'CALABARZON',
    'MIMAROPA Region',
    'Bicol Region',
    'Western Visayas',
    'Negros Island Region',
    'Central Visayas',
    'Eastern Visayas',
    'Zamboanga Peninsula',
    'Northern Mindanao',
    'Davao Region',
    'SOCCSKSARGEN',
    'Caraga',
    'Bangsamoro Autonomous Region in Muslim Mindanao (BARMM)'
  ]::text[])
$$;

REVOKE ALL ON FUNCTION public.hdc_is_supported_region(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_is_supported_region(text) TO hdc_app;

ALTER TABLE public.hdc_platform_role_applications
  DROP CONSTRAINT IF EXISTS hdc_platform_role_applications_controlled_locations;

CREATE OR REPLACE FUNCTION public.hdc_require_controlled_role_application_locations()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.answers->>'country' <> 'Philippines'
     OR NOT public.hdc_is_supported_location(NEW.answers->>'city')
     OR (
       NEW.role::text = 'technician'
       AND NOT public.hdc_is_supported_location(NEW.answers->>'serviceArea')
     )
     OR (
       NEW.role::text = 'business'
       AND NOT public.hdc_is_supported_location(NEW.answers->>'businessAddress')
     )
     OR (
       NEW.role::text = 'store'
       AND NOT public.hdc_is_supported_location(NEW.answers->>'storeAddress')
     )
     OR (
       NEW.role::text = 'supplier'
       AND NOT public.hdc_is_supported_region(NEW.answers->>'serviceRegions')
     ) THEN
    RAISE EXCEPTION 'Unsupported HDC role-application location'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_require_controlled_role_application_locations() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_require_controlled_role_application_locations() TO hdc_app;

DROP TRIGGER IF EXISTS hdc_platform_role_applications_controlled_locations
  ON public.hdc_platform_role_applications;
CREATE TRIGGER hdc_platform_role_applications_controlled_locations
BEFORE INSERT OR UPDATE OF role, answers ON public.hdc_platform_role_applications
FOR EACH ROW EXECUTE FUNCTION public.hdc_require_controlled_role_application_locations();

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0018', 'controlled_role_application_locations', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
