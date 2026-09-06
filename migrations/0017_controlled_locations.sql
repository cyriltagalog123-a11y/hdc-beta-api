-- HDC Build 24.2
-- Controlled Philippines locations for registration, profiles, and service requests.
-- Existing legacy rows are preserved by NOT VALID; every new or updated row
-- must use an HDC catalog value (member/profile blank is allowed until edited).

BEGIN;

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

ALTER TABLE public.hdc_member_profiles
  DROP CONSTRAINT IF EXISTS hdc_member_profiles_controlled_location;
ALTER TABLE public.hdc_member_profiles
  ADD CONSTRAINT hdc_member_profiles_controlled_location
  CHECK (location = '' OR public.hdc_is_supported_location(location)) NOT VALID;

ALTER TABLE public.hdc_platform_role_profiles
  DROP CONSTRAINT IF EXISTS hdc_platform_role_profiles_controlled_location;
ALTER TABLE public.hdc_platform_role_profiles
  ADD CONSTRAINT hdc_platform_role_profiles_controlled_location
  CHECK (location = '' OR public.hdc_is_supported_location(location)) NOT VALID;

ALTER TABLE public.hdc_service_requests
  DROP CONSTRAINT IF EXISTS hdc_service_requests_controlled_location;
ALTER TABLE public.hdc_service_requests
  ADD CONSTRAINT hdc_service_requests_controlled_location
  CHECK (public.hdc_is_supported_location(location)) NOT VALID;

COMMIT;
