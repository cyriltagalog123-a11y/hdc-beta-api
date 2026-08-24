-- HDC Build 15
-- Public technology catalog and payment-neutral purchase requests.
-- Apply after migration 0007 on an isolated PostgreSQL branch first.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_users') IS NULL
     OR to_regclass('public.hdc_user_roles') IS NULL
     OR to_regclass('public.hdc_platform_role_profiles') IS NULL
     OR to_regclass('public.hdc_product_listings') IS NULL
     OR to_regclass('public.hdc_product_listing_events') IS NULL
     OR to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0007'
     ) THEN
    RAISE EXCEPTION 'HDC migrations 0001 through 0007 must be applied first';
  END IF;
END
$$;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES (
  '0008', 'product_catalog_purchase_requests', false
)
ON CONFLICT (version) DO NOTHING;

-- This composite key prevents an order from naming a seller account that does
-- not own its listing. Public API responses never expose either account UUID.
CREATE UNIQUE INDEX IF NOT EXISTS hdc_product_listing_order_owner_role
  ON public.hdc_product_listings (id, seller_user_id, seller_role);

CREATE TABLE IF NOT EXISTS public.hdc_product_purchase_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_purchase_id text NOT NULL UNIQUE DEFAULT (
    'HDC-BUY-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
  ),
  idempotency_key uuid NOT NULL,
  listing_id uuid NOT NULL,
  seller_user_id uuid NOT NULL,
  seller_role text NOT NULL,
  buyer_user_id uuid NOT NULL
    REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  public_listing_id_snapshot text NOT NULL,
  listing_title_snapshot text NOT NULL,
  seller_name_snapshot text NOT NULL,
  buyer_name_snapshot text NOT NULL,
  buyer_public_member_id_snapshot text NOT NULL,
  quantity integer NOT NULL,
  currency text NOT NULL,
  unit_price_minor bigint NOT NULL,
  subtotal_minor bigint NOT NULL,
  buyer_note text NOT NULL DEFAULT '',
  seller_note text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'submitted',
  version bigint NOT NULL DEFAULT 1,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  cancelled_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_product_purchase_listing_owner
    FOREIGN KEY (listing_id, seller_user_id, seller_role)
    REFERENCES public.hdc_product_listings (id, seller_user_id, seller_role)
    ON DELETE RESTRICT,
  CONSTRAINT hdc_product_purchase_idempotency
    UNIQUE (buyer_user_id, idempotency_key),
  CONSTRAINT hdc_product_purchase_public_id
    CHECK (public_purchase_id ~ '^HDC-BUY-[A-F0-9]{12}$'),
  CONSTRAINT hdc_product_purchase_participants
    CHECK (seller_user_id <> buyer_user_id),
  CONSTRAINT hdc_product_purchase_seller_role
    CHECK (seller_role IN ('seller', 'supplier', 'store')),
  CONSTRAINT hdc_product_purchase_listing_reference
    CHECK (public_listing_id_snapshot ~ '^HDC-LST-[A-F0-9]{12}$'),
  CONSTRAINT hdc_product_purchase_title_length
    CHECK (char_length(listing_title_snapshot) BETWEEN 3 AND 160),
  CONSTRAINT hdc_product_purchase_seller_name_length
    CHECK (char_length(seller_name_snapshot) BETWEEN 2 AND 120),
  CONSTRAINT hdc_product_purchase_buyer_name_length
    CHECK (char_length(buyer_name_snapshot) BETWEEN 2 AND 120),
  CONSTRAINT hdc_product_purchase_member_reference_length
    CHECK (char_length(buyer_public_member_id_snapshot) BETWEEN 3 AND 40),
  CONSTRAINT hdc_product_purchase_quantity
    CHECK (quantity BETWEEN 1 AND 1000),
  CONSTRAINT hdc_product_purchase_currency
    CHECK (currency ~ '^[A-Z]{3}$'),
  CONSTRAINT hdc_product_purchase_unit_price
    CHECK (unit_price_minor BETWEEN 1 AND 999999999999),
  CONSTRAINT hdc_product_purchase_subtotal CHECK (
    subtotal_minor = unit_price_minor * quantity
    AND subtotal_minor BETWEEN 1 AND 999999999999000
  ),
  CONSTRAINT hdc_product_purchase_buyer_note_length
    CHECK (char_length(buyer_note) <= 1000),
  CONSTRAINT hdc_product_purchase_seller_note_length
    CHECK (char_length(seller_note) <= 1000),
  CONSTRAINT hdc_product_purchase_status CHECK (
    status IN ('submitted', 'accepted', 'declined', 'cancelled')
  ),
  CONSTRAINT hdc_product_purchase_state CHECK (
    (status = 'submitted' AND decided_at IS NULL AND cancelled_at IS NULL)
    OR (
      status IN ('accepted', 'declined')
      AND decided_at IS NOT NULL
      AND cancelled_at IS NULL
    )
    OR (
      status = 'cancelled'
      AND decided_at IS NULL
      AND cancelled_at IS NOT NULL
    )
  ),
  CONSTRAINT hdc_product_purchase_version CHECK (version > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS hdc_product_purchase_one_submitted
  ON public.hdc_product_purchase_requests (listing_id, buyer_user_id)
  WHERE status = 'submitted';

CREATE INDEX IF NOT EXISTS hdc_product_purchase_buyer_status
  ON public.hdc_product_purchase_requests (
    buyer_user_id, status, submitted_at DESC
  );

CREATE INDEX IF NOT EXISTS hdc_product_purchase_seller_status
  ON public.hdc_product_purchase_requests (
    seller_user_id, status, submitted_at DESC
  );

CREATE TABLE IF NOT EXISTS public.hdc_product_purchase_request_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_request_id uuid NOT NULL
    REFERENCES public.hdc_product_purchase_requests(id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  from_status text,
  to_status text NOT NULL,
  snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_product_purchase_event_type CHECK (
    event_type IN ('submitted', 'accepted', 'declined', 'cancelled')
  ),
  CONSTRAINT hdc_product_purchase_event_from_status CHECK (
    from_status IS NULL
    OR from_status IN ('submitted', 'accepted', 'declined', 'cancelled')
  ),
  CONSTRAINT hdc_product_purchase_event_to_status CHECK (
    to_status IN ('submitted', 'accepted', 'declined', 'cancelled')
  ),
  CONSTRAINT hdc_product_purchase_event_snapshot
    CHECK (jsonb_typeof(snapshot) = 'object')
);

CREATE INDEX IF NOT EXISTS hdc_product_purchase_events_request
  ON public.hdc_product_purchase_request_events (
    purchase_request_id, occurred_at DESC
  );

CREATE OR REPLACE FUNCTION public.hdc_guard_product_purchase_request_identity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF ROW(
    NEW.id,
    NEW.public_purchase_id,
    NEW.idempotency_key,
    NEW.listing_id,
    NEW.seller_user_id,
    NEW.seller_role,
    NEW.buyer_user_id,
    NEW.public_listing_id_snapshot,
    NEW.listing_title_snapshot,
    NEW.seller_name_snapshot,
    NEW.buyer_name_snapshot,
    NEW.buyer_public_member_id_snapshot,
    NEW.quantity,
    NEW.currency,
    NEW.unit_price_minor,
    NEW.subtotal_minor,
    NEW.buyer_note,
    NEW.submitted_at
  ) IS DISTINCT FROM ROW(
    OLD.id,
    OLD.public_purchase_id,
    OLD.idempotency_key,
    OLD.listing_id,
    OLD.seller_user_id,
    OLD.seller_role,
    OLD.buyer_user_id,
    OLD.public_listing_id_snapshot,
    OLD.listing_title_snapshot,
    OLD.seller_name_snapshot,
    OLD.buyer_name_snapshot,
    OLD.buyer_public_member_id_snapshot,
    OLD.quantity,
    OLD.currency,
    OLD.unit_price_minor,
    OLD.subtotal_minor,
    OLD.buyer_note,
    OLD.submitted_at
  ) THEN
    RAISE EXCEPTION 'HDC purchase identity and monetary evidence is immutable';
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_guard_product_purchase_request_identity()
  FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_product_purchase_requests_identity_guard
  ON public.hdc_product_purchase_requests;
CREATE TRIGGER hdc_product_purchase_requests_identity_guard
BEFORE UPDATE ON public.hdc_product_purchase_requests
FOR EACH ROW
EXECUTE FUNCTION public.hdc_guard_product_purchase_request_identity();

CREATE OR REPLACE FUNCTION public.hdc_touch_product_purchase_request()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  NEW.version := OLD.version + 1;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_touch_product_purchase_request()
  FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_product_purchase_requests_touch
  ON public.hdc_product_purchase_requests;
CREATE TRIGGER hdc_product_purchase_requests_touch
BEFORE UPDATE ON public.hdc_product_purchase_requests
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_product_purchase_request();

-- Closing a listing must not leave buyers waiting on requests that the seller
-- can no longer accept. Accepted requests remain as historical allocations.
CREATE OR REPLACE FUNCTION public.hdc_decline_requests_for_closed_listing()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status IN ('sold', 'archived')
     AND NEW.status IS DISTINCT FROM OLD.status THEN
    WITH declined AS (
      UPDATE public.hdc_product_purchase_requests
      SET status = 'declined',
          seller_note = 'The listing is no longer available.',
          decided_at = now()
      WHERE listing_id = NEW.id
        AND status = 'submitted'
      RETURNING id
    )
    INSERT INTO public.hdc_product_purchase_request_events (
      purchase_request_id, actor_user_id, event_type,
      from_status, to_status, snapshot
    )
    SELECT
      declined.id, NULL, 'declined', 'submitted', 'declined',
      jsonb_build_object('reason', 'listing_closed')
    FROM declined;
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_decline_requests_for_closed_listing()
  FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_product_listing_close_purchase_requests
  ON public.hdc_product_listings;
CREATE TRIGGER hdc_product_listing_close_purchase_requests
AFTER UPDATE OF status ON public.hdc_product_listings
FOR EACH ROW EXECUTE FUNCTION public.hdc_decline_requests_for_closed_listing();

-- A suspended, revoked, changed, or deleted selling role must also close its
-- still-pending purchase requests. Existing accepted records are preserved.
CREATE OR REPLACE FUNCTION public.hdc_decline_requests_for_inactive_seller()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  should_decline boolean := false;
BEGIN
  IF OLD.role::text IN ('seller', 'supplier', 'store') THEN
    IF TG_OP = 'DELETE' THEN
      should_decline := true;
    ELSE
      should_decline := NEW.is_active = false
        OR NEW.status <> 'active'
        OR NEW.role::text <> OLD.role::text;
    END IF;
  END IF;

  IF should_decline THEN
    WITH declined AS (
      UPDATE public.hdc_product_purchase_requests
      SET status = 'declined',
          seller_note = 'The selling workspace is no longer active.',
          decided_at = now()
      WHERE seller_user_id = OLD.user_id
        AND seller_role = OLD.role::text
        AND status = 'submitted'
      RETURNING id
    )
    INSERT INTO public.hdc_product_purchase_request_events (
      purchase_request_id, actor_user_id, event_type,
      from_status, to_status, snapshot
    )
    SELECT
      declined.id, NULL, 'declined', 'submitted', 'declined',
      jsonb_build_object('reason', 'selling_role_inactive')
    FROM declined;
  END IF;

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_decline_requests_for_inactive_seller()
  FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_user_roles_decline_purchase_requests_update
  ON public.hdc_user_roles;
DROP TRIGGER IF EXISTS hdc_user_roles_decline_purchase_requests_delete
  ON public.hdc_user_roles;
CREATE TRIGGER hdc_user_roles_decline_purchase_requests_update
AFTER UPDATE OF role, is_active, status ON public.hdc_user_roles
FOR EACH ROW EXECUTE FUNCTION public.hdc_decline_requests_for_inactive_seller();
CREATE TRIGGER hdc_user_roles_decline_purchase_requests_delete
AFTER DELETE ON public.hdc_user_roles
FOR EACH ROW EXECUTE FUNCTION public.hdc_decline_requests_for_inactive_seller();

ALTER TABLE public.hdc_product_purchase_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_product_purchase_request_events
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.hdc_product_purchase_requests FROM PUBLIC;
REVOKE ALL ON public.hdc_product_purchase_request_events FROM PUBLIC;

COMMENT ON TABLE public.hdc_product_purchase_requests IS
  'Payment-neutral buyer requests for active HDC technology listings.';
COMMENT ON COLUMN public.hdc_product_purchase_requests.status IS
  'Accepted allocates inventory but does not prove payment or fulfillment.';
COMMENT ON TABLE public.hdc_product_purchase_request_events IS
  'Immutable purchase-request lifecycle evidence using HDC-owned IDs.';

COMMIT;
