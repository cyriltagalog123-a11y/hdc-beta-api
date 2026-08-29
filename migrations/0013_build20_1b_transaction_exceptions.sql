-- HDC Build 20.1B
-- Participant-authorized schedule changes, mutually approved price changes,
-- and auditable cancellation/no-show/non-response records.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0012'
     )
     OR to_regclass('public.hdc_service_transactions') IS NULL THEN
    RAISE EXCEPTION 'HDC migration 0012 and service transactions are required';
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.hdc_is_transaction_participant(
  expected_transaction_id text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.hdc_service_transactions transaction_row
    WHERE transaction_row.id = expected_transaction_id
      AND public.hdc_current_user_id() IN (
        transaction_row.customer_id,
        transaction_row.technician_id
      )
  )
$$;

REVOKE ALL ON FUNCTION public.hdc_is_transaction_participant(text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_is_transaction_participant(text)
  TO hdc_app;

CREATE TABLE IF NOT EXISTS public.hdc_service_schedule_changes (
  id text PRIMARY KEY,
  transaction_id text NOT NULL
    REFERENCES public.hdc_service_transactions(id) ON DELETE RESTRICT,
  client_reference text NOT NULL,
  proposed_by uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  proposed_for timestamptz NOT NULL,
  note text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending',
  decided_by uuid REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1,
  CONSTRAINT hdc_service_schedule_changes_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_schedule_changes_client_reference
    UNIQUE (transaction_id, proposed_by, client_reference),
  CONSTRAINT hdc_service_schedule_changes_client_reference_length
    CHECK (char_length(client_reference) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_schedule_changes_note_length
    CHECK (char_length(note) <= 1000),
  CONSTRAINT hdc_service_schedule_changes_status
    CHECK (status IN ('pending', 'accepted', 'declined', 'withdrawn')),
  CONSTRAINT hdc_service_schedule_changes_decision
    CHECK (
      (status = 'pending' AND decided_by IS NULL AND decided_at IS NULL) OR
      (status = 'withdrawn' AND decided_at IS NOT NULL) OR
      (status IN ('accepted', 'declined') AND
        decided_by IS NOT NULL AND decided_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS hdc_schedule_one_pending_per_transaction
  ON public.hdc_service_schedule_changes (transaction_id)
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS hdc_schedule_transaction_created_idx
  ON public.hdc_service_schedule_changes (transaction_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.hdc_service_change_orders (
  id text PRIMARY KEY,
  transaction_id text NOT NULL
    REFERENCES public.hdc_service_transactions(id) ON DELETE RESTRICT,
  client_reference text NOT NULL,
  proposed_by uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  reason text NOT NULL,
  service_fee_minor bigint NOT NULL,
  parts_cost_minor bigint NOT NULL DEFAULT 0,
  total_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'PHP',
  status text NOT NULL DEFAULT 'pending',
  decided_by uuid REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1,
  CONSTRAINT hdc_service_change_orders_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_change_orders_client_reference
    UNIQUE (transaction_id, proposed_by, client_reference),
  CONSTRAINT hdc_service_change_orders_client_reference_length
    CHECK (char_length(client_reference) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_change_orders_reason_length
    CHECK (char_length(reason) BETWEEN 5 AND 2000),
  CONSTRAINT hdc_service_change_orders_amounts
    CHECK (
      service_fee_minor >= 0 AND
      parts_cost_minor >= 0 AND
      total_minor = service_fee_minor + parts_cost_minor AND
      total_minor <= 100000000000
    ),
  CONSTRAINT hdc_service_change_orders_currency
    CHECK (currency ~ '^[A-Z]{3}$'),
  CONSTRAINT hdc_service_change_orders_status
    CHECK (status IN ('pending', 'accepted', 'declined', 'withdrawn', 'superseded')),
  CONSTRAINT hdc_service_change_orders_decision
    CHECK (
      (status = 'pending' AND decided_by IS NULL AND decided_at IS NULL) OR
      (status IN ('withdrawn', 'superseded') AND decided_at IS NOT NULL) OR
      (status IN ('accepted', 'declined') AND
        decided_by IS NOT NULL AND decided_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS hdc_change_order_one_pending_per_transaction
  ON public.hdc_service_change_orders (transaction_id)
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS hdc_change_order_transaction_created_idx
  ON public.hdc_service_change_orders (transaction_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.hdc_service_transaction_exceptions (
  id text PRIMARY KEY,
  transaction_id text NOT NULL
    REFERENCES public.hdc_service_transactions(id) ON DELETE RESTRICT,
  client_reference text NOT NULL,
  reported_by uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  exception_type text NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'recorded',
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  CONSTRAINT hdc_service_transaction_exceptions_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_transaction_exceptions_client_reference
    UNIQUE (transaction_id, reported_by, client_reference),
  CONSTRAINT hdc_service_transaction_exceptions_client_reference_length
    CHECK (char_length(client_reference) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_transaction_exceptions_type
    CHECK (exception_type IN (
      'cancellation', 'customerNoShow', 'technicianNoShow',
      'customerNonResponse', 'other'
    )),
  CONSTRAINT hdc_service_transaction_exceptions_reason_length
    CHECK (char_length(reason) BETWEEN 5 AND 2000),
  CONSTRAINT hdc_service_transaction_exceptions_status
    CHECK (status IN ('recorded', 'underReview', 'resolved')),
  CONSTRAINT hdc_service_transaction_exceptions_resolution
    CHECK (
      (status <> 'resolved' AND resolved_at IS NULL) OR
      (status = 'resolved' AND resolved_at IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS hdc_transaction_exceptions_created_idx
  ON public.hdc_service_transaction_exceptions (transaction_id, created_at DESC);

DROP TRIGGER IF EXISTS hdc_service_schedule_changes_touch
  ON public.hdc_service_schedule_changes;
CREATE TRIGGER hdc_service_schedule_changes_touch
BEFORE UPDATE ON public.hdc_service_schedule_changes
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_workflow_row();

DROP TRIGGER IF EXISTS hdc_service_change_orders_touch
  ON public.hdc_service_change_orders;
CREATE TRIGGER hdc_service_change_orders_touch
BEFORE UPDATE ON public.hdc_service_change_orders
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_workflow_row();

ALTER TABLE public.hdc_service_schedule_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_service_change_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_service_transaction_exceptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hdc_service_schedule_changes_participant_select
  ON public.hdc_service_schedule_changes;
CREATE POLICY hdc_service_schedule_changes_participant_select
ON public.hdc_service_schedule_changes
FOR SELECT TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_schedule_changes_participant_insert
  ON public.hdc_service_schedule_changes;
CREATE POLICY hdc_service_schedule_changes_participant_insert
ON public.hdc_service_schedule_changes
FOR INSERT TO hdc_app
WITH CHECK (
  proposed_by = public.hdc_current_user_id() AND
  public.hdc_is_transaction_participant(transaction_id)
);

DROP POLICY IF EXISTS hdc_service_schedule_changes_participant_update
  ON public.hdc_service_schedule_changes;
CREATE POLICY hdc_service_schedule_changes_participant_update
ON public.hdc_service_schedule_changes
FOR UPDATE TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id))
WITH CHECK (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_change_orders_participant_select
  ON public.hdc_service_change_orders;
CREATE POLICY hdc_service_change_orders_participant_select
ON public.hdc_service_change_orders
FOR SELECT TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_change_orders_participant_insert
  ON public.hdc_service_change_orders;
CREATE POLICY hdc_service_change_orders_participant_insert
ON public.hdc_service_change_orders
FOR INSERT TO hdc_app
WITH CHECK (
  proposed_by = public.hdc_current_user_id() AND
  public.hdc_is_transaction_participant(transaction_id)
);

DROP POLICY IF EXISTS hdc_service_change_orders_participant_update
  ON public.hdc_service_change_orders;
CREATE POLICY hdc_service_change_orders_participant_update
ON public.hdc_service_change_orders
FOR UPDATE TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id))
WITH CHECK (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_transaction_exceptions_participant_select
  ON public.hdc_service_transaction_exceptions;
CREATE POLICY hdc_service_transaction_exceptions_participant_select
ON public.hdc_service_transaction_exceptions
FOR SELECT TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_transaction_exceptions_participant_insert
  ON public.hdc_service_transaction_exceptions;
CREATE POLICY hdc_service_transaction_exceptions_participant_insert
ON public.hdc_service_transaction_exceptions
FOR INSERT TO hdc_app
WITH CHECK (
  reported_by = public.hdc_current_user_id() AND
  public.hdc_is_transaction_participant(transaction_id)
);

GRANT SELECT, INSERT, UPDATE
  ON public.hdc_service_schedule_changes,
     public.hdc_service_change_orders
  TO hdc_app;
GRANT SELECT, INSERT
  ON public.hdc_service_transaction_exceptions
  TO hdc_app;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES (
  '0013', 'build20_1b_transaction_exceptions', false
)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = false;

COMMIT;
