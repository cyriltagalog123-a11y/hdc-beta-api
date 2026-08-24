-- HDC Build 14
-- Account-scoped technology product listings and seller-managed sold state.
-- Apply after migration 0006 on an isolated PostgreSQL branch first.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_users') IS NULL
     OR to_regclass('public.hdc_user_roles') IS NULL
     OR to_regclass('public.hdc_platform_role_profiles') IS NULL
     OR to_regclass('public.hdc_schema_migrations') IS NULL THEN
    RAISE EXCEPTION 'HDC migrations 0001 through 0006 must be applied first';
  END IF;
END
$$;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES (
  '0007', 'marketplace_listing_dashboard', false
)
ON CONFLICT (version) DO NOTHING;

-- The composite identity ties every listing to one approved role profile under
-- one immutable HDC account UUID. A listing never belongs to an internal role.
CREATE UNIQUE INDEX IF NOT EXISTS hdc_role_profile_listing_identity
  ON public.hdc_platform_role_profiles (id, user_id, role);

CREATE TABLE IF NOT EXISTS public.hdc_product_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_listing_id text NOT NULL UNIQUE DEFAULT (
    'HDC-LST-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
  ),
  seller_profile_id uuid NOT NULL,
  seller_user_id uuid NOT NULL,
  seller_role text NOT NULL,
  category_code text NOT NULL,
  title text NOT NULL,
  description text NOT NULL,
  item_condition text NOT NULL,
  currency text NOT NULL DEFAULT 'PHP',
  unit_price_minor bigint NOT NULL,
  stock_quantity integer NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  version bigint NOT NULL DEFAULT 1,
  published_at timestamptz,
  sold_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_product_listing_seller_profile
    FOREIGN KEY (seller_profile_id, seller_user_id, seller_role)
    REFERENCES public.hdc_platform_role_profiles (id, user_id, role)
    ON DELETE RESTRICT,
  CONSTRAINT hdc_product_listing_public_id
    CHECK (public_listing_id ~ '^HDC-LST-[A-F0-9]{12}$'),
  CONSTRAINT hdc_product_listing_seller_role
    CHECK (seller_role IN ('seller', 'supplier', 'store')),
  CONSTRAINT hdc_product_listing_category
    CHECK (category_code IN (
      'computers', 'laptops', 'mobile_devices', 'pos_equipment',
      'networking', 'parts_components', 'accessories', 'software_licenses',
      'other_technology'
    )),
  CONSTRAINT hdc_product_listing_title_length
    CHECK (char_length(title) BETWEEN 3 AND 160),
  CONSTRAINT hdc_product_listing_description_length
    CHECK (char_length(description) BETWEEN 10 AND 4000),
  CONSTRAINT hdc_product_listing_condition CHECK (
    item_condition IN ('new', 'open_box', 'used', 'refurbished', 'for_parts')
  ),
  CONSTRAINT hdc_product_listing_currency
    CHECK (currency ~ '^[A-Z]{3}$'),
  CONSTRAINT hdc_product_listing_price
    CHECK (unit_price_minor BETWEEN 1 AND 999999999999),
  CONSTRAINT hdc_product_listing_stock
    CHECK (stock_quantity BETWEEN 0 AND 1000000),
  CONSTRAINT hdc_product_listing_status CHECK (
    status IN ('draft', 'active', 'paused', 'sold', 'archived')
  ),
  CONSTRAINT hdc_product_listing_active_stock
    CHECK (status <> 'active' OR stock_quantity > 0),
  CONSTRAINT hdc_product_listing_sold_state
    CHECK (
      (status = 'sold' AND stock_quantity = 0 AND sold_at IS NOT NULL)
      OR status <> 'sold'
    ),
  CONSTRAINT hdc_product_listing_sold_timestamp
    CHECK (sold_at IS NULL OR status IN ('sold', 'archived')),
  CONSTRAINT hdc_product_listing_archived_timestamp
    CHECK (archived_at IS NULL OR status = 'archived'),
  CONSTRAINT hdc_product_listing_version CHECK (version > 0)
);

CREATE INDEX IF NOT EXISTS hdc_product_listing_owner_status
  ON public.hdc_product_listings (seller_user_id, status, updated_at DESC);

CREATE INDEX IF NOT EXISTS hdc_product_listing_public_catalog
  ON public.hdc_product_listings (category_code, updated_at DESC)
  WHERE status = 'active';

CREATE TABLE IF NOT EXISTS public.hdc_product_listing_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL
    REFERENCES public.hdc_product_listings(id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  from_status text,
  to_status text NOT NULL,
  snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_product_listing_event_type
    CHECK (event_type IN ('created', 'updated', 'status_changed')),
  CONSTRAINT hdc_product_listing_event_from_status CHECK (
    from_status IS NULL
    OR from_status IN ('draft', 'active', 'paused', 'sold', 'archived')
  ),
  CONSTRAINT hdc_product_listing_event_to_status CHECK (
    to_status IN ('draft', 'active', 'paused', 'sold', 'archived')
  ),
  CONSTRAINT hdc_product_listing_event_snapshot
    CHECK (jsonb_typeof(snapshot) = 'object')
);

CREATE INDEX IF NOT EXISTS hdc_product_listing_events_listing
  ON public.hdc_product_listing_events (listing_id, occurred_at DESC);

CREATE OR REPLACE FUNCTION public.hdc_touch_product_listing()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  NEW.version := OLD.version + 1;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_touch_product_listing() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_product_listings_touch
  ON public.hdc_product_listings;
CREATE TRIGGER hdc_product_listings_touch
BEFORE UPDATE ON public.hdc_product_listings
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_product_listing();

-- Removing a selling role must stop its public listings without deleting the
-- seller's history. Re-approval does not silently republish them.
CREATE OR REPLACE FUNCTION public.hdc_pause_listings_for_inactive_role()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.role::text IN ('seller', 'supplier', 'store') THEN
      WITH paused AS (
        UPDATE public.hdc_product_listings
        SET status = 'paused'
        WHERE seller_user_id = OLD.user_id
          AND seller_role = OLD.role::text
          AND status = 'active'
        RETURNING id
      )
      INSERT INTO public.hdc_product_listing_events (
        listing_id, actor_user_id, event_type, from_status, to_status, snapshot
      )
      SELECT
        paused.id, NULL, 'status_changed', 'active', 'paused',
        jsonb_build_object('reason', 'selling_role_inactive')
      FROM paused;
    END IF;
    RETURN OLD;
  END IF;

  IF OLD.role::text IN ('seller', 'supplier', 'store')
     AND (
       NEW.is_active = false
       OR NEW.status <> 'active'
       OR NEW.role::text <> OLD.role::text
     ) THEN
    WITH paused AS (
      UPDATE public.hdc_product_listings
      SET status = 'paused'
      WHERE seller_user_id = OLD.user_id
        AND seller_role = OLD.role::text
        AND status = 'active'
      RETURNING id
    )
    INSERT INTO public.hdc_product_listing_events (
      listing_id, actor_user_id, event_type, from_status, to_status, snapshot
    )
    SELECT
      paused.id, NULL, 'status_changed', 'active', 'paused',
      jsonb_build_object('reason', 'selling_role_inactive')
    FROM paused;
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_pause_listings_for_inactive_role()
  FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_user_roles_pause_product_listings
  ON public.hdc_user_roles;
DROP TRIGGER IF EXISTS hdc_user_roles_pause_product_listings_update
  ON public.hdc_user_roles;
DROP TRIGGER IF EXISTS hdc_user_roles_pause_product_listings_delete
  ON public.hdc_user_roles;
CREATE TRIGGER hdc_user_roles_pause_product_listings_update
AFTER UPDATE OF role, is_active, status ON public.hdc_user_roles
FOR EACH ROW EXECUTE FUNCTION public.hdc_pause_listings_for_inactive_role();
CREATE TRIGGER hdc_user_roles_pause_product_listings_delete
AFTER DELETE ON public.hdc_user_roles
FOR EACH ROW EXECUTE FUNCTION public.hdc_pause_listings_for_inactive_role();

ALTER TABLE public.hdc_product_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_product_listing_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.hdc_product_listings FROM PUBLIC;
REVOKE ALL ON public.hdc_product_listing_events FROM PUBLIC;

COMMENT ON TABLE public.hdc_product_listings IS
  'Account-scoped technology listings owned by an approved Seller, Supplier, or Store profile.';
COMMENT ON COLUMN public.hdc_product_listings.sold_at IS
  'Seller-recorded sold state; this timestamp does not by itself prove payment.';
COMMENT ON TABLE public.hdc_product_listing_events IS
  'Immutable listing lifecycle evidence without internal-role or provider credentials.';

COMMIT;
