-- HDC Build 21
-- Payment-neutral service ledger and immutable participant-confirmed receipts.
-- No row created here represents provider-verified money movement.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0013'
     )
     OR to_regprocedure('public.hdc_is_transaction_participant(text)') IS NULL THEN
    RAISE EXCEPTION 'HDC migration 0013 is required before Build 21 payments';
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.hdc_service_payments (
  id text PRIMARY KEY,
  transaction_id text NOT NULL
    REFERENCES public.hdc_service_transactions(id) ON DELETE RESTRICT,
  client_reference text NOT NULL,
  recorded_by uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  amount_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'PHP',
  payment_method text NOT NULL,
  status text NOT NULL DEFAULT 'recorded',
  note text NOT NULL DEFAULT '',
  external_reference text,
  confirmed_by uuid REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  confirmed_at timestamptz,
  refunded_minor bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1,
  CONSTRAINT hdc_service_payments_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_payments_client_reference_length
    CHECK (char_length(client_reference) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_payments_client_reference_unique
    UNIQUE (transaction_id, recorded_by, client_reference),
  CONSTRAINT hdc_service_payments_amount
    CHECK (amount_minor BETWEEN 1 AND 100000000000),
  CONSTRAINT hdc_service_payments_currency
    CHECK (currency ~ '^[A-Z]{3}$'),
  CONSTRAINT hdc_service_payments_method
    CHECK (payment_method IN (
      'cash', 'bankTransfer', 'eWallet', 'cardExternal', 'other'
    )),
  CONSTRAINT hdc_service_payments_status
    CHECK (status IN (
      'recorded', 'confirmed', 'rejected', 'partiallyRefunded',
      'refunded', 'cancelled'
    )),
  CONSTRAINT hdc_service_payments_note_length
    CHECK (char_length(note) <= 2000),
  CONSTRAINT hdc_service_payments_external_reference_length
    CHECK (
      external_reference IS NULL OR
      char_length(external_reference) BETWEEN 2 AND 120
    ),
  CONSTRAINT hdc_service_payments_confirmation
    CHECK (
      (status IN ('recorded', 'cancelled') AND
        confirmed_by IS NULL AND confirmed_at IS NULL) OR
      (status IN ('confirmed', 'partiallyRefunded', 'refunded') AND
        confirmed_by IS NOT NULL AND confirmed_at IS NOT NULL) OR
      (status = 'rejected' AND confirmed_at IS NOT NULL)
    ),
  CONSTRAINT hdc_service_payments_refund
    CHECK (
      refunded_minor BETWEEN 0 AND amount_minor AND
      (status = 'refunded') = (refunded_minor = amount_minor) AND
      (status = 'partiallyRefunded') =
        (refunded_minor > 0 AND refunded_minor < amount_minor)
    )
);

CREATE INDEX IF NOT EXISTS hdc_service_payments_transaction_created_idx
  ON public.hdc_service_payments (transaction_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.hdc_service_payment_events (
  id text PRIMARY KEY,
  payment_id text NOT NULL
    REFERENCES public.hdc_service_payments(id) ON DELETE RESTRICT,
  transaction_id text NOT NULL
    REFERENCES public.hdc_service_transactions(id) ON DELETE RESTRICT,
  actor_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  related_event_id text
    REFERENCES public.hdc_service_payment_events(id) ON DELETE RESTRICT,
  event_type text NOT NULL,
  amount_minor bigint,
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_service_payment_events_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_payment_events_type
    CHECK (event_type IN (
      'recorded', 'confirmed', 'rejected', 'cancelled',
      'refundRecorded', 'refundConfirmed'
    )),
  CONSTRAINT hdc_service_payment_events_amount
    CHECK (amount_minor IS NULL OR amount_minor > 0),
  CONSTRAINT hdc_service_payment_events_note_length
    CHECK (char_length(note) <= 2000),
  CONSTRAINT hdc_service_payment_events_relation
    CHECK (
      (event_type = 'refundConfirmed' AND related_event_id IS NOT NULL) OR
      (event_type <> 'refundConfirmed' AND related_event_id IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS hdc_service_payment_events_payment_created_idx
  ON public.hdc_service_payment_events (payment_id, created_at, id);

CREATE TABLE IF NOT EXISTS public.hdc_service_receipts (
  id text PRIMARY KEY,
  payment_id text NOT NULL
    REFERENCES public.hdc_service_payments(id) ON DELETE RESTRICT,
  transaction_id text NOT NULL
    REFERENCES public.hdc_service_transactions(id) ON DELETE RESTRICT,
  receipt_type text NOT NULL,
  amount_minor bigint NOT NULL,
  currency text NOT NULL,
  issued_to uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  issued_by uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  verification_level text NOT NULL DEFAULT 'participantConfirmed',
  snapshot jsonb NOT NULL,
  issued_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_service_receipts_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_receipts_type
    CHECK (receipt_type IN ('payment', 'refund')),
  CONSTRAINT hdc_service_receipts_amount
    CHECK (amount_minor > 0),
  CONSTRAINT hdc_service_receipts_currency
    CHECK (currency ~ '^[A-Z]{3}$'),
  CONSTRAINT hdc_service_receipts_verification
    CHECK (verification_level = 'participantConfirmed'),
  CONSTRAINT hdc_service_receipts_snapshot_object
    CHECK (jsonb_typeof(snapshot) = 'object')
);

CREATE INDEX IF NOT EXISTS hdc_service_receipts_transaction_issued_idx
  ON public.hdc_service_receipts (transaction_id, issued_at DESC);

DROP TRIGGER IF EXISTS hdc_service_payments_touch
  ON public.hdc_service_payments;
CREATE TRIGGER hdc_service_payments_touch
BEFORE UPDATE ON public.hdc_service_payments
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_workflow_row();

ALTER TABLE public.hdc_service_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_service_payment_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_service_receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hdc_service_payments_participant_select
  ON public.hdc_service_payments;
CREATE POLICY hdc_service_payments_participant_select
ON public.hdc_service_payments
FOR SELECT TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_payments_participant_insert
  ON public.hdc_service_payments;
CREATE POLICY hdc_service_payments_participant_insert
ON public.hdc_service_payments
FOR INSERT TO hdc_app
WITH CHECK (
  recorded_by = public.hdc_current_user_id() AND
  public.hdc_is_transaction_participant(transaction_id)
);

DROP POLICY IF EXISTS hdc_service_payments_participant_update
  ON public.hdc_service_payments;
CREATE POLICY hdc_service_payments_participant_update
ON public.hdc_service_payments
FOR UPDATE TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id))
WITH CHECK (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_payment_events_participant_select
  ON public.hdc_service_payment_events;
CREATE POLICY hdc_service_payment_events_participant_select
ON public.hdc_service_payment_events
FOR SELECT TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_payment_events_participant_insert
  ON public.hdc_service_payment_events;
CREATE POLICY hdc_service_payment_events_participant_insert
ON public.hdc_service_payment_events
FOR INSERT TO hdc_app
WITH CHECK (
  actor_id = public.hdc_current_user_id() AND
  public.hdc_is_transaction_participant(transaction_id)
);

DROP POLICY IF EXISTS hdc_service_receipts_participant_select
  ON public.hdc_service_receipts;
CREATE POLICY hdc_service_receipts_participant_select
ON public.hdc_service_receipts
FOR SELECT TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_receipts_participant_insert
  ON public.hdc_service_receipts;
CREATE POLICY hdc_service_receipts_participant_insert
ON public.hdc_service_receipts
FOR INSERT TO hdc_app
WITH CHECK (
  issued_by = public.hdc_current_user_id() AND
  public.hdc_is_transaction_participant(transaction_id)
);

GRANT SELECT, INSERT, UPDATE ON public.hdc_service_payments TO hdc_app;
GRANT SELECT, INSERT ON public.hdc_service_payment_events TO hdc_app;
GRANT SELECT, INSERT ON public.hdc_service_receipts TO hdc_app;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES (
  '0014', 'build21_payment_receipts', false
)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = false;

COMMIT;
