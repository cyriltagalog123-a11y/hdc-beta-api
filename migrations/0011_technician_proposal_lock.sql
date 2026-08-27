-- HDC Build 20 production hotfix
-- Let an authenticated Technician lock an open request while creating a
-- proposal without granting permission to modify that customer-owned row.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0010'
     ) THEN
    RAISE EXCEPTION 'Migration 0010 must be applied before 0011';
  END IF;

  IF to_regclass('public.hdc_service_requests') IS NULL THEN
    RAISE EXCEPTION 'HDC service-request table is missing';
  END IF;
END
$$;

DROP POLICY IF EXISTS hdc_service_requests_technician_lock
  ON public.hdc_service_requests;
CREATE POLICY hdc_service_requests_technician_lock
ON public.hdc_service_requests
FOR UPDATE TO hdc_app
USING (
  status IN ('open', 'receivingOffers')
  AND customer_id <> public.hdc_current_user_id()
  AND public.hdc_has_role('technician')
)
WITH CHECK (false);

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES (
  '0011', 'technician_proposal_lock', false
)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = false;

COMMIT;
