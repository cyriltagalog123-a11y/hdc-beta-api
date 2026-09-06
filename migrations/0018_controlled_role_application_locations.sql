-- HDC Build 24.2
-- Enforce controlled Philippines locations inside structured platform-role applications.
-- Legacy applications remain readable through NOT VALID; new or updated rows must
-- use the HDC catalog for every location-bearing answer.

BEGIN;

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

COMMIT;
