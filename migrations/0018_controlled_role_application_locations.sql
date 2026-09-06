-- HDC Build 24.2
-- Enforce controlled Philippines locations inside structured platform-role applications.
-- Legacy applications remain readable through NOT VALID; new or updated rows must
-- use the HDC catalog for every location-bearing answer.

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
ALTER TABLE public.hdc_platform_role_applications
  ADD CONSTRAINT hdc_platform_role_applications_controlled_locations
  CHECK (
    answers->>'country' = 'Philippines'
    AND public.hdc_is_supported_location(answers->>'city')
    AND (
      role::text <> 'technician'
      OR public.hdc_is_supported_location(answers->>'serviceArea')
    )
    AND (
      role::text <> 'business'
      OR public.hdc_is_supported_location(answers->>'businessAddress')
    )
    AND (
      role::text <> 'store'
      OR public.hdc_is_supported_location(answers->>'storeAddress')
    )
    AND (
      role::text <> 'supplier'
      OR public.hdc_is_supported_region(answers->>'serviceRegions')
    )
  ) NOT VALID;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0018', 'controlled_role_application_locations', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
