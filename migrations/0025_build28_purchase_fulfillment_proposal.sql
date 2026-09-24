-- Build 28: preserve the buyer's fulfillment proposal with the purchase.
-- Existing requests have no recorded proposal and remain distinguishable.
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_product_purchase_requests') IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0024') THEN
    RAISE EXCEPTION 'HDC migration 0024 must be applied first';
  END IF;
END
$$;

ALTER TABLE public.hdc_product_purchase_requests
  ADD COLUMN fulfillment_method text,
  ADD COLUMN fulfillment_location text,
  ADD COLUMN fulfillment_timing text,
  ADD COLUMN fulfillment_fee_minor bigint;

ALTER TABLE public.hdc_product_purchase_requests
  ADD CONSTRAINT hdc_product_purchase_fulfillment_proposal CHECK (
    (fulfillment_method IS NULL AND fulfillment_location IS NULL
      AND fulfillment_timing IS NULL AND fulfillment_fee_minor IS NULL)
    OR (fulfillment_method IS NOT NULL AND fulfillment_location IS NOT NULL
      AND fulfillment_timing IS NOT NULL AND fulfillment_fee_minor IS NOT NULL
      AND fulfillment_method IN ('pickup', 'delivery')
      AND char_length(fulfillment_location) BETWEEN 5 AND 240
      AND char_length(fulfillment_timing) BETWEEN 5 AND 240
      AND fulfillment_fee_minor BETWEEN 0 AND 999999999)
  );

CREATE OR REPLACE FUNCTION public.hdc_guard_product_purchase_fulfillment()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  IF ROW(NEW.fulfillment_method, NEW.fulfillment_location,
      NEW.fulfillment_timing, NEW.fulfillment_fee_minor)
     IS DISTINCT FROM
     ROW(OLD.fulfillment_method, OLD.fulfillment_location,
      OLD.fulfillment_timing, OLD.fulfillment_fee_minor) THEN
    RAISE EXCEPTION 'HDC purchase fulfillment proposal is immutable';
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_guard_product_purchase_fulfillment() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_guard_product_purchase_fulfillment() TO hdc_app;
CREATE TRIGGER hdc_product_purchase_fulfillment_guard
BEFORE UPDATE ON public.hdc_product_purchase_requests
FOR EACH ROW EXECUTE FUNCTION public.hdc_guard_product_purchase_fulfillment();

CREATE INDEX hdc_product_catalog_page
  ON public.hdc_product_listings (published_at DESC, id DESC)
  WHERE status = 'active' AND stock_quantity > 0;
CREATE INDEX hdc_product_seller_page
  ON public.hdc_product_listings (seller_user_id, created_at DESC, id DESC);
CREATE INDEX hdc_product_buyer_purchase_page
  ON public.hdc_product_purchase_requests (buyer_user_id, submitted_at DESC, id DESC);
CREATE INDEX hdc_product_seller_purchase_page
  ON public.hdc_product_purchase_requests (seller_user_id, submitted_at DESC, id DESC);

INSERT INTO public.hdc_schema_migrations (version, migration_name, is_baseline)
VALUES ('0025', 'build28_purchase_fulfillment_proposal', false)
ON CONFLICT (version) DO UPDATE SET migration_name = EXCLUDED.migration_name;

COMMIT;
