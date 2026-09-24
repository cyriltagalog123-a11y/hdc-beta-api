-- Build 29: participant-approved cancellation after acceptance.
-- A pending request does not release stock. Approval restores it once.
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_product_purchase_requests') IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0025') THEN
    RAISE EXCEPTION 'HDC migration 0025 must be applied first';
  END IF;
END
$$;

ALTER TABLE public.hdc_product_purchase_requests
  ADD COLUMN cancellation_requested_by uuid REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  ADD COLUMN cancellation_reason text,
  ADD COLUMN cancellation_requested_at timestamptz,
  ADD COLUMN cancellation_responded_at timestamptz,
  ADD COLUMN cancellation_response_note text NOT NULL DEFAULT '',
  ADD COLUMN stock_released_at timestamptz;

ALTER TABLE public.hdc_product_purchase_requests
  DROP CONSTRAINT hdc_product_purchase_state;
ALTER TABLE public.hdc_product_purchase_requests
  ADD CONSTRAINT hdc_product_purchase_state CHECK (
    (status = 'submitted' AND decided_at IS NULL AND cancelled_at IS NULL
      AND fulfilled_at IS NULL AND completed_at IS NULL)
    OR (status = 'accepted' AND decided_at IS NOT NULL AND cancelled_at IS NULL
      AND fulfilled_at IS NULL AND completed_at IS NULL)
    OR (status = 'fulfilled' AND decided_at IS NOT NULL AND cancelled_at IS NULL
      AND fulfilled_at IS NOT NULL AND completed_at IS NULL)
    OR (status = 'completed' AND decided_at IS NOT NULL AND cancelled_at IS NULL
      AND fulfilled_at IS NOT NULL AND completed_at IS NOT NULL)
    OR (status = 'declined' AND decided_at IS NOT NULL AND cancelled_at IS NULL
      AND fulfilled_at IS NULL AND completed_at IS NULL)
    OR (status = 'cancelled' AND cancelled_at IS NOT NULL
      AND fulfilled_at IS NULL AND completed_at IS NULL
      AND ((decided_at IS NULL AND stock_released_at IS NULL)
        OR (decided_at IS NOT NULL AND stock_released_at IS NOT NULL)))
  );

ALTER TABLE public.hdc_product_purchase_requests
  ADD CONSTRAINT hdc_product_purchase_cancellation_proposal CHECK (
    (cancellation_requested_by IS NULL AND cancellation_reason IS NULL
      AND cancellation_requested_at IS NULL AND cancellation_responded_at IS NULL
      AND cancellation_response_note = '')
    OR (cancellation_requested_by IS NOT NULL
      AND cancellation_requested_by IN (buyer_user_id, seller_user_id)
      AND cancellation_reason IS NOT NULL
      AND char_length(cancellation_reason) BETWEEN 10 AND 500
      AND cancellation_requested_at IS NOT NULL
      AND status IN ('accepted', 'cancelled')
      AND char_length(cancellation_response_note) <= 1000
      AND ((status = 'accepted' AND cancellation_responded_at IS NULL)
        OR (status = 'cancelled' AND cancellation_responded_at IS NOT NULL)))
  ),
  ADD CONSTRAINT hdc_product_purchase_stock_release CHECK (
    stock_released_at IS NULL OR
    (status = 'cancelled' AND decided_at IS NOT NULL
      AND cancellation_requested_by IS NOT NULL)
  );

ALTER TABLE public.hdc_product_purchase_request_events
  DROP CONSTRAINT hdc_product_purchase_event_type;
ALTER TABLE public.hdc_product_purchase_request_events
  ADD CONSTRAINT hdc_product_purchase_event_type CHECK (
    event_type IN ('submitted', 'accepted', 'fulfilled', 'completed', 'declined',
      'cancelled', 'cancellation_requested', 'cancellation_declined')
  );

CREATE OR REPLACE FUNCTION public.hdc_guard_product_purchase_stock_release()
RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
  IF OLD.stock_released_at IS NOT NULL
     AND NEW.stock_released_at IS DISTINCT FROM OLD.stock_released_at THEN
    RAISE EXCEPTION 'HDC restored purchase stock cannot be released twice';
  END IF;
  RETURN NEW;
END
$$;
REVOKE ALL ON FUNCTION public.hdc_guard_product_purchase_stock_release() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_guard_product_purchase_stock_release() TO hdc_app;
CREATE TRIGGER hdc_product_purchase_stock_release_guard
BEFORE UPDATE ON public.hdc_product_purchase_requests
FOR EACH ROW EXECUTE FUNCTION public.hdc_guard_product_purchase_stock_release();

INSERT INTO public.hdc_schema_migrations (version, migration_name, is_baseline)
VALUES ('0026', 'build29_order_recovery', false)
ON CONFLICT (version) DO UPDATE SET migration_name = EXCLUDED.migration_name;
COMMIT;
