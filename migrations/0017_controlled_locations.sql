-- HDC Build 24.2
-- Controlled Philippines locations for registration, profiles, and service requests.
-- Legacy rows remain untouched, while database triggers enforce the HDC catalog
-- on every new row and every update that changes a controlled location field.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0016'
     ) THEN
    RAISE EXCEPTION 'HDC migrations 0000 through 0016 must be applied first';
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.hdc_is_supported_location(value text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
  SELECT value = ANY (ARRAY[
    'Metro Manila, National Capital Region, Philippines',
    'Abra, Cordillera Administrative Region, Philippines','Apayao, Cordillera Administrative Region, Philippines','Benguet, Cordillera Administrative Region, Philippines','Ifugao, Cordillera Administrative Region, Philippines','Kalinga, Cordillera Administrative Region, Philippines','Mountain Province, Cordillera Administrative Region, Philippines','Baguio City, Cordillera Administrative Region, Philippines',
    'Ilocos Norte, Ilocos Region, Philippines','Ilocos Sur, Ilocos Region, Philippines','La Union, Ilocos Region, Philippines','Pangasinan, Ilocos Region, Philippines',
    'Batanes, Cagayan Valley, Philippines','Cagayan, Cagayan Valley, Philippines','Isabela, Cagayan Valley, Philippines','Nueva Vizcaya, Cagayan Valley, Philippines','Quirino, Cagayan Valley, Philippines',
    'Aurora, Central Luzon, Philippines','Bataan, Central Luzon, Philippines','Bulacan, Central Luzon, Philippines','Nueva Ecija, Central Luzon, Philippines','Pampanga, Central Luzon, Philippines','Tarlac, Central Luzon, Philippines','Zambales, Central Luzon, Philippines','Angeles City, Central Luzon, Philippines','Olongapo City, Central Luzon, Philippines',
    'Batangas, CALABARZON, Philippines','Cavite, CALABARZON, Philippines','Laguna, CALABARZON, Philippines','Quezon, CALABARZON, Philippines','Rizal, CALABARZON, Philippines','Lucena City, CALABARZON, Philippines',
    'Marinduque, MIMAROPA Region, Philippines','Occidental Mindoro, MIMAROPA Region, Philippines','Oriental Mindoro, MIMAROPA Region, Philippines','Palawan, MIMAROPA Region, Philippines','Romblon, MIMAROPA Region, Philippines','Puerto Princesa City, MIMAROPA Region, Philippines',
    'Albay, Bicol Region, Philippines','Camarines Norte, Bicol Region, Philippines','Camarines Sur, Bicol Region, Philippines','Catanduanes, Bicol Region, Philippines','Masbate, Bicol Region, Philippines','Sorsogon, Bicol Region, Philippines',
    'Aklan, Western Visayas, Philippines','Antique, Western Visayas, Philippines','Capiz, Western Visayas, Philippines','Guimaras, Western Visayas, Philippines','Iloilo, Western Visayas, Philippines','Iloilo City, Western Visayas, Philippines',
    'Negros Occidental, Negros Island Region, Philippines','Negros Oriental, Negros Island Region, Philippines','Siquijor, Negros Island Region, Philippines','Bacolod City, Negros Island Region, Philippines',
    'Bohol, Central Visayas, Philippines','Cebu, Central Visayas, Philippines','Cebu City, Central Visayas, Philippines','Lapu-Lapu City, Central Visayas, Philippines','Mandaue City, Central Visayas, Philippines',
    'Biliran, Eastern Visayas, Philippines','Eastern Samar, Eastern Visayas, Philippines','Leyte, Eastern Visayas, Philippines','Northern Samar, Eastern Visayas, Philippines','Samar, Eastern Visayas, Philippines','Southern Leyte, Eastern Visayas, Philippines','Tacloban City, Eastern Visayas, Philippines',
    'Zamboanga del Norte, Zamboanga Peninsula, Philippines','Zamboanga del Sur, Zamboanga Peninsula, Philippines','Zamboanga Sibugay, Zamboanga Peninsula, Philippines','Sulu, Zamboanga Peninsula, Philippines','Zamboanga City, Zamboanga Peninsula, Philippines',
    'Bukidnon, Northern Mindanao, Philippines','Camiguin, Northern Mindanao, Philippines','Lanao del Norte, Northern Mindanao, Philippines','Misamis Occidental, Northern Mindanao, Philippines','Misamis Oriental, Northern Mindanao, Philippines','Cagayan de Oro City, Northern Mindanao, Philippines','Iligan City, Northern Mindanao, Philippines',
    'Davao de Oro, Davao Region, Philippines','Davao del Norte, Davao Region, Philippines','Davao del Sur, Davao Region, Philippines','Davao Occidental, Davao Region, Philippines','Davao Oriental, Davao Region, Philippines','Davao City, Davao Region, Philippines',
    'Cotabato, SOCCSKSARGEN, Philippines','Sarangani, SOCCSKSARGEN, Philippines','South Cotabato, SOCCSKSARGEN, Philippines','Sultan Kudarat, SOCCSKSARGEN, Philippines','General Santos City, SOCCSKSARGEN, Philippines',
    'Agusan del Norte, Caraga, Philippines','Agusan del Sur, Caraga, Philippines','Dinagat Islands, Caraga, Philippines','Surigao del Norte, Caraga, Philippines','Surigao del Sur, Caraga, Philippines','Butuan City, Caraga, Philippines',
    'Basilan, Bangsamoro Autonomous Region in Muslim Mindanao (BARMM), Philippines','Lanao del Sur, Bangsamoro Autonomous Region in Muslim Mindanao (BARMM), Philippines','Maguindanao del Norte, Bangsamoro Autonomous Region in Muslim Mindanao (BARMM), Philippines','Maguindanao del Sur, Bangsamoro Autonomous Region in Muslim Mindanao (BARMM), Philippines','Tawi-Tawi, Bangsamoro Autonomous Region in Muslim Mindanao (BARMM), Philippines','Cotabato City, Bangsamoro Autonomous Region in Muslim Mindanao (BARMM), Philippines'
  ]::text[])
$$;

REVOKE ALL ON FUNCTION public.hdc_is_supported_location(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_is_supported_location(text) TO hdc_app;

ALTER TABLE public.hdc_member_profiles
  DROP CONSTRAINT IF EXISTS hdc_member_profiles_controlled_location;
ALTER TABLE public.hdc_platform_role_profiles
  DROP CONSTRAINT IF EXISTS hdc_platform_role_profiles_controlled_location;
ALTER TABLE public.hdc_service_requests
  DROP CONSTRAINT IF EXISTS hdc_service_requests_controlled_location;

CREATE OR REPLACE FUNCTION public.hdc_require_optional_controlled_location()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.location <> ''
     AND NOT public.hdc_is_supported_location(NEW.location) THEN
    RAISE EXCEPTION 'Unsupported HDC location'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

CREATE OR REPLACE FUNCTION public.hdc_require_controlled_location()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT public.hdc_is_supported_location(NEW.location) THEN
    RAISE EXCEPTION 'Unsupported HDC location'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_require_optional_controlled_location() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.hdc_require_controlled_location() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_require_optional_controlled_location() TO hdc_app;
GRANT EXECUTE ON FUNCTION public.hdc_require_controlled_location() TO hdc_app;

DROP TRIGGER IF EXISTS hdc_member_profiles_controlled_location
  ON public.hdc_member_profiles;
CREATE TRIGGER hdc_member_profiles_controlled_location
BEFORE INSERT OR UPDATE OF location ON public.hdc_member_profiles
FOR EACH ROW EXECUTE FUNCTION public.hdc_require_optional_controlled_location();

DROP TRIGGER IF EXISTS hdc_platform_role_profiles_controlled_location
  ON public.hdc_platform_role_profiles;
CREATE TRIGGER hdc_platform_role_profiles_controlled_location
BEFORE INSERT OR UPDATE OF location ON public.hdc_platform_role_profiles
FOR EACH ROW EXECUTE FUNCTION public.hdc_require_optional_controlled_location();

DROP TRIGGER IF EXISTS hdc_service_requests_controlled_location
  ON public.hdc_service_requests;
CREATE TRIGGER hdc_service_requests_controlled_location
BEFORE INSERT OR UPDATE OF location ON public.hdc_service_requests
FOR EACH ROW EXECUTE FUNCTION public.hdc_require_controlled_location();

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0017', 'controlled_locations', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
