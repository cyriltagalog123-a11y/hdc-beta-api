-- HDC Sprint 6.4C/D
-- Server-side authority for service requests, proposals, acceptance handoff,
-- and service transactions.
--
-- Apply on an isolated Neon branch first. The Flutter client never receives
-- this database connection or executes this migration directly.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_users') IS NULL THEN
    RAISE EXCEPTION 'HDC auth prerequisite public.hdc_users is missing';
  END IF;

  IF to_regclass('public.hdc_user_roles') IS NULL THEN
    RAISE EXCEPTION 'HDC auth prerequisite public.hdc_user_roles is missing';
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hdc_app') THEN
    CREATE ROLE hdc_app NOLOGIN;
  END IF;

  IF NOT pg_has_role(current_user, 'hdc_app', 'MEMBER') THEN
    EXECUTE format('GRANT hdc_app TO %I', current_user);
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.hdc_current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('hdc.user_id', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION public.hdc_has_role(expected_role text)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT expected_role = ANY(
    string_to_array(current_setting('hdc.roles', true), ',')
  )
$$;

REVOKE ALL ON FUNCTION public.hdc_current_user_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.hdc_has_role(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_current_user_id() TO hdc_app;
GRANT EXECUTE ON FUNCTION public.hdc_has_role(text) TO hdc_app;

CREATE TABLE IF NOT EXISTS public.hdc_service_requests (
  id text PRIMARY KEY,
  customer_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  customer_name text NOT NULL,
  title text NOT NULL,
  category_id text NOT NULL,
  category_name text NOT NULL,
  description text NOT NULL,
  location text NOT NULL,
  preferred_date timestamptz NOT NULL,
  preferred_time text NOT NULL,
  urgency text NOT NULL,
  minimum_budget numeric(12, 2),
  maximum_budget numeric(12, 2),
  status text NOT NULL DEFAULT 'open',
  offer_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1,
  CONSTRAINT hdc_service_requests_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_requests_title_length
    CHECK (char_length(title) BETWEEN 4 AND 140),
  CONSTRAINT hdc_service_requests_category_id_length
    CHECK (char_length(category_id) BETWEEN 1 AND 100),
  CONSTRAINT hdc_service_requests_category_name_length
    CHECK (char_length(category_name) BETWEEN 2 AND 100),
  CONSTRAINT hdc_service_requests_description_length
    CHECK (char_length(description) BETWEEN 10 AND 5000),
  CONSTRAINT hdc_service_requests_location_length
    CHECK (char_length(location) BETWEEN 2 AND 300),
  CONSTRAINT hdc_service_requests_preferred_time_length
    CHECK (char_length(preferred_time) BETWEEN 1 AND 80),
  CONSTRAINT hdc_service_requests_urgency
    CHECK (urgency IN ('flexible', 'normal', 'urgent', 'emergency')),
  CONSTRAINT hdc_service_requests_status
    CHECK (status IN (
      'draft', 'open', 'receivingOffers', 'technicianSelected',
      'inProgress', 'completed', 'cancelled', 'expired'
    )),
  CONSTRAINT hdc_service_requests_minimum_budget
    CHECK (minimum_budget IS NULL OR minimum_budget >= 0),
  CONSTRAINT hdc_service_requests_maximum_budget
    CHECK (maximum_budget IS NULL OR maximum_budget >= 0),
  CONSTRAINT hdc_service_requests_budget_order
    CHECK (
      minimum_budget IS NULL OR maximum_budget IS NULL OR
      minimum_budget <= maximum_budget
    ),
  CONSTRAINT hdc_service_requests_offer_count
    CHECK (offer_count >= 0)
);

CREATE TABLE IF NOT EXISTS public.hdc_proposals (
  id text PRIMARY KEY,
  request_id text NOT NULL
    REFERENCES public.hdc_service_requests(id) ON DELETE CASCADE,
  technician_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'draft',
  service_fee numeric(12, 2) NOT NULL,
  parts_arrangement text NOT NULL,
  estimated_parts_cost numeric(12, 2),
  earliest_arrival timestamptz NOT NULL,
  estimated_duration_minutes integer NOT NULL,
  warranty_type text NOT NULL,
  custom_warranty_days integer,
  diagnosis text NOT NULL,
  repair_approach text NOT NULL,
  professional_notes text NOT NULL DEFAULT '',
  reputation jsonb NOT NULL DEFAULT '{}'::jsonb,
  quality_score integer NOT NULL,
  attachment_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  submitted_at timestamptz,
  viewed_at timestamptz,
  shortlisted_at timestamptz,
  accepted_at timestamptz,
  declined_at timestamptz,
  expired_at timestamptz,
  withdrawn_at timestamptz,
  version bigint NOT NULL DEFAULT 1,
  CONSTRAINT hdc_proposals_request_technician_unique
    UNIQUE (request_id, technician_id),
  CONSTRAINT hdc_proposals_status
    CHECK (status IN (
      'draft', 'submitted', 'viewed', 'shortlisted', 'accepted',
      'declined', 'expired', 'withdrawn'
    )),
  CONSTRAINT hdc_proposals_service_fee
    CHECK (service_fee >= 0),
  CONSTRAINT hdc_proposals_parts_arrangement
    CHECK (parts_arrangement IN (
      'none', 'customerSupplies', 'technicianSupplies'
    )),
  CONSTRAINT hdc_proposals_estimated_parts_cost
    CHECK (estimated_parts_cost IS NULL OR estimated_parts_cost >= 0),
  CONSTRAINT hdc_proposals_duration
    CHECK (estimated_duration_minutes BETWEEN 1 AND 43200),
  CONSTRAINT hdc_proposals_warranty_type
    CHECK (warranty_type IN (
      'none', 'sevenDays', 'thirtyDays', 'ninetyDays', 'custom'
    )),
  CONSTRAINT hdc_proposals_custom_warranty
    CHECK (
      (warranty_type = 'custom' AND custom_warranty_days BETWEEN 1 AND 3650) OR
      (warranty_type <> 'custom' AND custom_warranty_days IS NULL)
    ),
  CONSTRAINT hdc_proposals_quality_score
    CHECK (quality_score BETWEEN 0 AND 100),
  CONSTRAINT hdc_proposals_reputation_object
    CHECK (jsonb_typeof(reputation) = 'object'),
  CONSTRAINT hdc_proposals_attachment_array
    CHECK (jsonb_typeof(attachment_ids) = 'array')
);

CREATE TABLE IF NOT EXISTS public.hdc_transaction_seeds (
  id text PRIMARY KEY,
  request_id text NOT NULL UNIQUE
    REFERENCES public.hdc_service_requests(id) ON DELETE RESTRICT,
  proposal_id text NOT NULL UNIQUE
    REFERENCES public.hdc_proposals(id) ON DELETE RESTRICT,
  customer_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  accepted_estimate numeric(12, 2) NOT NULL,
  status text NOT NULL DEFAULT 'readyForWorkspace',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_transaction_seeds_estimate
    CHECK (accepted_estimate >= 0),
  CONSTRAINT hdc_transaction_seeds_status
    CHECK (status IN ('readyForWorkspace', 'consumed', 'cancelled'))
);

CREATE TABLE IF NOT EXISTS public.hdc_service_transactions (
  id text PRIMARY KEY,
  seed_id text NOT NULL UNIQUE
    REFERENCES public.hdc_transaction_seeds(id) ON DELETE RESTRICT,
  request_id text NOT NULL UNIQUE
    REFERENCES public.hdc_service_requests(id) ON DELETE RESTRICT,
  proposal_id text NOT NULL UNIQUE
    REFERENCES public.hdc_proposals(id) ON DELETE RESTRICT,
  customer_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  customer_name text NOT NULL,
  technician_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  technician_name text NOT NULL,
  request_title text NOT NULL,
  category_name text NOT NULL,
  service_location text NOT NULL,
  status text NOT NULL DEFAULT 'confirmed',
  accepted_terms jsonb NOT NULL,
  activity jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1,
  CONSTRAINT hdc_service_transactions_status
    CHECK (status IN (
      'created', 'confirmed', 'scheduled', 'technicianEnRoute', 'arrived',
      'inProgress', 'awaitingCustomerConfirmation', 'completed',
      'cancelled', 'disputed'
    )),
  CONSTRAINT hdc_service_transactions_terms_object
    CHECK (jsonb_typeof(accepted_terms) = 'object'),
  CONSTRAINT hdc_service_transactions_activity_array
    CHECK (jsonb_typeof(activity) = 'array')
);

CREATE INDEX IF NOT EXISTS hdc_service_requests_customer_updated_idx
  ON public.hdc_service_requests (customer_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS hdc_service_requests_marketplace_idx
  ON public.hdc_service_requests (status, created_at DESC)
  WHERE status IN ('open', 'receivingOffers');
CREATE INDEX IF NOT EXISTS hdc_proposals_request_updated_idx
  ON public.hdc_proposals (request_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS hdc_proposals_technician_updated_idx
  ON public.hdc_proposals (technician_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS hdc_transaction_seeds_participants_idx
  ON public.hdc_transaction_seeds (customer_id, technician_id, created_at DESC);
CREATE INDEX IF NOT EXISTS hdc_service_transactions_customer_updated_idx
  ON public.hdc_service_transactions (customer_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS hdc_service_transactions_technician_updated_idx
  ON public.hdc_service_transactions (technician_id, updated_at DESC);

CREATE OR REPLACE FUNCTION public.hdc_touch_workflow_row()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  NEW.version := OLD.version + 1;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS hdc_service_requests_touch
  ON public.hdc_service_requests;
CREATE TRIGGER hdc_service_requests_touch
BEFORE UPDATE ON public.hdc_service_requests
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_workflow_row();

DROP TRIGGER IF EXISTS hdc_proposals_touch ON public.hdc_proposals;
CREATE TRIGGER hdc_proposals_touch
BEFORE UPDATE ON public.hdc_proposals
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_workflow_row();

DROP TRIGGER IF EXISTS hdc_service_transactions_touch
  ON public.hdc_service_transactions;
CREATE TRIGGER hdc_service_transactions_touch
BEFORE UPDATE ON public.hdc_service_transactions
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_workflow_row();

CREATE OR REPLACE FUNCTION public.hdc_refresh_request_offer_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_request_id text;
  active_offer_count integer;
BEGIN
  IF TG_OP = 'DELETE' AND OLD.status = 'draft' THEN
    RETURN OLD;
  END IF;

  target_request_id := COALESCE(NEW.request_id, OLD.request_id);

  SELECT count(*)::integer
  INTO active_offer_count
  FROM public.hdc_proposals
  WHERE request_id = target_request_id
    AND status NOT IN ('draft', 'withdrawn', 'expired');

  UPDATE public.hdc_service_requests
  SET
    offer_count = active_offer_count,
    status = CASE
      WHEN status = 'open' AND active_offer_count > 0 THEN 'receivingOffers'
      WHEN status = 'receivingOffers' AND active_offer_count = 0 THEN 'open'
      ELSE status
    END
  WHERE id = target_request_id;

  RETURN COALESCE(NEW, OLD);
END
$$;

REVOKE ALL ON FUNCTION public.hdc_refresh_request_offer_count() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_proposals_refresh_request
  ON public.hdc_proposals;
CREATE TRIGGER hdc_proposals_refresh_request
AFTER INSERT OR UPDATE OF status OR DELETE ON public.hdc_proposals
FOR EACH ROW EXECUTE FUNCTION public.hdc_refresh_request_offer_count();

ALTER TABLE public.hdc_service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_transaction_seeds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_service_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hdc_service_requests_select
  ON public.hdc_service_requests;
CREATE POLICY hdc_service_requests_select
ON public.hdc_service_requests
FOR SELECT TO hdc_app
USING (
  customer_id = public.hdc_current_user_id()
  OR (
    status IN ('open', 'receivingOffers')
    AND public.hdc_has_role('technician')
  )
  OR EXISTS (
    SELECT 1
    FROM public.hdc_service_transactions transaction_row
    WHERE transaction_row.request_id = hdc_service_requests.id
      AND public.hdc_current_user_id() IN (
        transaction_row.customer_id,
        transaction_row.technician_id
      )
  )
);

DROP POLICY IF EXISTS hdc_service_requests_insert
  ON public.hdc_service_requests;
CREATE POLICY hdc_service_requests_insert
ON public.hdc_service_requests
FOR INSERT TO hdc_app
WITH CHECK (
  customer_id = public.hdc_current_user_id()
  AND public.hdc_has_role('customer')
);

DROP POLICY IF EXISTS hdc_service_requests_update
  ON public.hdc_service_requests;
CREATE POLICY hdc_service_requests_update
ON public.hdc_service_requests
FOR UPDATE TO hdc_app
USING (
  customer_id = public.hdc_current_user_id()
  OR EXISTS (
    SELECT 1
    FROM public.hdc_service_transactions transaction_row
    WHERE transaction_row.request_id = hdc_service_requests.id
      AND public.hdc_current_user_id() IN (
        transaction_row.customer_id,
        transaction_row.technician_id
      )
  )
)
WITH CHECK (
  customer_id = public.hdc_current_user_id()
  OR EXISTS (
    SELECT 1
    FROM public.hdc_service_transactions transaction_row
    WHERE transaction_row.request_id = hdc_service_requests.id
      AND public.hdc_current_user_id() IN (
        transaction_row.customer_id,
        transaction_row.technician_id
      )
  )
);

DROP POLICY IF EXISTS hdc_service_requests_delete
  ON public.hdc_service_requests;
CREATE POLICY hdc_service_requests_delete
ON public.hdc_service_requests
FOR DELETE TO hdc_app
USING (customer_id = public.hdc_current_user_id());

DROP POLICY IF EXISTS hdc_proposals_select ON public.hdc_proposals;
CREATE POLICY hdc_proposals_select
ON public.hdc_proposals
FOR SELECT TO hdc_app
USING (
  technician_id = public.hdc_current_user_id()
  OR EXISTS (
    SELECT 1
    FROM public.hdc_service_requests request_row
    WHERE request_row.id = hdc_proposals.request_id
      AND request_row.customer_id = public.hdc_current_user_id()
  )
);

DROP POLICY IF EXISTS hdc_proposals_insert ON public.hdc_proposals;
CREATE POLICY hdc_proposals_insert
ON public.hdc_proposals
FOR INSERT TO hdc_app
WITH CHECK (
  technician_id = public.hdc_current_user_id()
  AND public.hdc_has_role('technician')
  AND EXISTS (
    SELECT 1
    FROM public.hdc_service_requests request_row
    WHERE request_row.id = hdc_proposals.request_id
      AND request_row.status IN ('open', 'receivingOffers')
  )
);

DROP POLICY IF EXISTS hdc_proposals_update ON public.hdc_proposals;
CREATE POLICY hdc_proposals_update
ON public.hdc_proposals
FOR UPDATE TO hdc_app
USING (
  technician_id = public.hdc_current_user_id()
  OR EXISTS (
    SELECT 1
    FROM public.hdc_service_requests request_row
    WHERE request_row.id = hdc_proposals.request_id
      AND request_row.customer_id = public.hdc_current_user_id()
  )
)
WITH CHECK (
  technician_id = public.hdc_current_user_id()
  OR EXISTS (
    SELECT 1
    FROM public.hdc_service_requests request_row
    WHERE request_row.id = hdc_proposals.request_id
      AND request_row.customer_id = public.hdc_current_user_id()
  )
);

DROP POLICY IF EXISTS hdc_proposals_delete ON public.hdc_proposals;
CREATE POLICY hdc_proposals_delete
ON public.hdc_proposals
FOR DELETE TO hdc_app
USING (technician_id = public.hdc_current_user_id());

DROP POLICY IF EXISTS hdc_transaction_seeds_select
  ON public.hdc_transaction_seeds;
CREATE POLICY hdc_transaction_seeds_select
ON public.hdc_transaction_seeds
FOR SELECT TO hdc_app
USING (
  public.hdc_current_user_id() IN (customer_id, technician_id)
);

DROP POLICY IF EXISTS hdc_transaction_seeds_insert
  ON public.hdc_transaction_seeds;
CREATE POLICY hdc_transaction_seeds_insert
ON public.hdc_transaction_seeds
FOR INSERT TO hdc_app
WITH CHECK (customer_id = public.hdc_current_user_id());

DROP POLICY IF EXISTS hdc_transaction_seeds_update
  ON public.hdc_transaction_seeds;
CREATE POLICY hdc_transaction_seeds_update
ON public.hdc_transaction_seeds
FOR UPDATE TO hdc_app
USING (
  public.hdc_current_user_id() IN (customer_id, technician_id)
)
WITH CHECK (
  public.hdc_current_user_id() IN (customer_id, technician_id)
);

DROP POLICY IF EXISTS hdc_service_transactions_select
  ON public.hdc_service_transactions;
CREATE POLICY hdc_service_transactions_select
ON public.hdc_service_transactions
FOR SELECT TO hdc_app
USING (
  public.hdc_current_user_id() IN (customer_id, technician_id)
);

DROP POLICY IF EXISTS hdc_service_transactions_insert
  ON public.hdc_service_transactions;
CREATE POLICY hdc_service_transactions_insert
ON public.hdc_service_transactions
FOR INSERT TO hdc_app
WITH CHECK (customer_id = public.hdc_current_user_id());

DROP POLICY IF EXISTS hdc_service_transactions_update
  ON public.hdc_service_transactions;
CREATE POLICY hdc_service_transactions_update
ON public.hdc_service_transactions
FOR UPDATE TO hdc_app
USING (
  public.hdc_current_user_id() IN (customer_id, technician_id)
)
WITH CHECK (
  public.hdc_current_user_id() IN (customer_id, technician_id)
);

GRANT USAGE ON SCHEMA public TO hdc_app;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.hdc_service_requests,
     public.hdc_proposals,
     public.hdc_transaction_seeds,
     public.hdc_service_transactions
  TO hdc_app;

COMMIT;
