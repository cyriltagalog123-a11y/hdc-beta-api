-- HDC post-Build 21
-- Structured participant documents and an auditable dispute workflow.
-- Binary attachments remain behind the provider-neutral object-storage boundary.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0014'
     )
     OR to_regprocedure('public.hdc_is_transaction_participant(text)') IS NULL THEN
    RAISE EXCEPTION 'HDC migration 0014 is required before documents/disputes';
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.hdc_service_disputes (
  id text PRIMARY KEY,
  transaction_id text NOT NULL
    REFERENCES public.hdc_service_transactions(id) ON DELETE RESTRICT,
  client_reference text NOT NULL,
  opened_by uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  reason_code text NOT NULL,
  summary text NOT NULL,
  requested_outcome text NOT NULL,
  prior_transaction_status text NOT NULL,
  status text NOT NULL DEFAULT 'open',
  resolution_outcome text,
  resolution_note text NOT NULL DEFAULT '',
  resolved_by uuid REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1,
  CONSTRAINT hdc_service_disputes_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_disputes_client_reference
    UNIQUE (transaction_id, opened_by, client_reference),
  CONSTRAINT hdc_service_disputes_client_reference_length
    CHECK (char_length(client_reference) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_disputes_reason
    CHECK (reason_code IN (
      'workQuality', 'scopeOrPrice', 'payment', 'noShow',
      'conductOrSafety', 'completion', 'other'
    )),
  CONSTRAINT hdc_service_disputes_summary_length
    CHECK (char_length(summary) BETWEEN 20 AND 5000),
  CONSTRAINT hdc_service_disputes_requested_outcome
    CHECK (requested_outcome IN (
      'continueService', 'cancelService', 'partialRefund',
      'fullRefund', 'other'
    )),
  CONSTRAINT hdc_service_disputes_prior_status
    CHECK (prior_transaction_status IN (
      'created', 'confirmed', 'scheduled', 'technicianEnRoute', 'arrived',
      'inProgress', 'awaitingCustomerConfirmation', 'completed', 'cancelled'
    )),
  CONSTRAINT hdc_service_disputes_status
    CHECK (status IN ('open', 'underReview', 'resolved', 'withdrawn')),
  CONSTRAINT hdc_service_disputes_resolution_outcome
    CHECK (
      resolution_outcome IS NULL OR resolution_outcome IN (
        'serviceContinues', 'serviceCompleted', 'serviceCancelled',
        'partialRefund', 'fullRefund', 'noAdjustment', 'other'
      )
    ),
  CONSTRAINT hdc_service_disputes_resolution_note_length
    CHECK (char_length(resolution_note) <= 5000),
  CONSTRAINT hdc_service_disputes_resolution
    CHECK (
      (status IN ('open', 'underReview') AND
        resolution_outcome IS NULL AND resolved_by IS NULL AND
        resolved_at IS NULL) OR
      (status = 'withdrawn' AND resolved_at IS NOT NULL) OR
      (status = 'resolved' AND resolution_outcome IS NOT NULL AND
        resolved_by IS NOT NULL AND resolved_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS hdc_service_disputes_one_active
  ON public.hdc_service_disputes (transaction_id)
  WHERE status IN ('open', 'underReview');
CREATE INDEX IF NOT EXISTS hdc_service_disputes_status_created_idx
  ON public.hdc_service_disputes (status, created_at DESC);
CREATE INDEX IF NOT EXISTS hdc_service_disputes_transaction_created_idx
  ON public.hdc_service_disputes (transaction_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.hdc_service_dispute_events (
  id text PRIMARY KEY,
  dispute_id text NOT NULL
    REFERENCES public.hdc_service_disputes(id) ON DELETE RESTRICT,
  transaction_id text NOT NULL
    REFERENCES public.hdc_service_transactions(id) ON DELETE RESTRICT,
  actor_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  event_type text NOT NULL,
  message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_service_dispute_events_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_dispute_events_type
    CHECK (event_type IN (
      'opened', 'reviewStarted', 'participantNote', 'withdrawn', 'resolved'
    )),
  CONSTRAINT hdc_service_dispute_events_message_length
    CHECK (char_length(message) BETWEEN 2 AND 5000)
);

CREATE INDEX IF NOT EXISTS hdc_service_dispute_events_created_idx
  ON public.hdc_service_dispute_events (dispute_id, created_at, id);

CREATE TABLE IF NOT EXISTS public.hdc_service_documents (
  id text PRIMARY KEY,
  transaction_id text NOT NULL
    REFERENCES public.hdc_service_transactions(id) ON DELETE RESTRICT,
  dispute_id text
    REFERENCES public.hdc_service_disputes(id) ON DELETE RESTRICT,
  client_reference text NOT NULL,
  created_by uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  document_type text NOT NULL,
  title text NOT NULL,
  content_text text NOT NULL,
  content_sha256 text NOT NULL,
  byte_size integer NOT NULL,
  storage_mode text NOT NULL DEFAULT 'hdcManaged',
  mime_type text NOT NULL DEFAULT 'text/plain',
  visibility text NOT NULL DEFAULT 'participants',
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1,
  CONSTRAINT hdc_service_documents_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_documents_client_reference_unique
    UNIQUE (transaction_id, created_by, client_reference),
  CONSTRAINT hdc_service_documents_client_reference_length
    CHECK (char_length(client_reference) BETWEEN 3 AND 100),
  CONSTRAINT hdc_service_documents_type
    CHECK (document_type IN (
      'serviceReport', 'warranty', 'paymentEvidence',
      'receiptNote', 'disputeEvidence', 'other'
    )),
  CONSTRAINT hdc_service_documents_title_length
    CHECK (char_length(title) BETWEEN 3 AND 160),
  CONSTRAINT hdc_service_documents_content_length
    CHECK (char_length(content_text) BETWEEN 2 AND 20000),
  CONSTRAINT hdc_service_documents_sha256
    CHECK (content_sha256 ~ '^[a-f0-9]{64}$'),
  CONSTRAINT hdc_service_documents_byte_size
    CHECK (byte_size BETWEEN 2 AND 100000),
  CONSTRAINT hdc_service_documents_storage
    CHECK (storage_mode = 'hdcManaged'),
  CONSTRAINT hdc_service_documents_mime_type
    CHECK (mime_type = 'text/plain'),
  CONSTRAINT hdc_service_documents_visibility
    CHECK (visibility IN ('participants', 'internal')),
  CONSTRAINT hdc_service_documents_status
    CHECK (status IN ('active', 'superseded', 'removed')),
  CONSTRAINT hdc_service_documents_dispute_link
    CHECK (
      document_type <> 'disputeEvidence' OR dispute_id IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS hdc_service_documents_transaction_created_idx
  ON public.hdc_service_documents (transaction_id, created_at DESC);
CREATE INDEX IF NOT EXISTS hdc_service_documents_dispute_created_idx
  ON public.hdc_service_documents (dispute_id, created_at DESC)
  WHERE dispute_id IS NOT NULL;

DROP TRIGGER IF EXISTS hdc_service_disputes_touch
  ON public.hdc_service_disputes;
CREATE TRIGGER hdc_service_disputes_touch
BEFORE UPDATE ON public.hdc_service_disputes
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_workflow_row();

DROP TRIGGER IF EXISTS hdc_service_documents_touch
  ON public.hdc_service_documents;
CREATE TRIGGER hdc_service_documents_touch
BEFORE UPDATE ON public.hdc_service_documents
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_workflow_row();

ALTER TABLE public.hdc_service_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_service_dispute_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_service_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hdc_service_disputes_participant_select
  ON public.hdc_service_disputes;
CREATE POLICY hdc_service_disputes_participant_select
ON public.hdc_service_disputes
FOR SELECT TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_disputes_participant_insert
  ON public.hdc_service_disputes;
CREATE POLICY hdc_service_disputes_participant_insert
ON public.hdc_service_disputes
FOR INSERT TO hdc_app
WITH CHECK (
  opened_by = public.hdc_current_user_id() AND
  public.hdc_is_transaction_participant(transaction_id)
);

DROP POLICY IF EXISTS hdc_service_disputes_participant_update
  ON public.hdc_service_disputes;
CREATE POLICY hdc_service_disputes_participant_update
ON public.hdc_service_disputes
FOR UPDATE TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id))
WITH CHECK (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_dispute_events_participant_select
  ON public.hdc_service_dispute_events;
CREATE POLICY hdc_service_dispute_events_participant_select
ON public.hdc_service_dispute_events
FOR SELECT TO hdc_app
USING (public.hdc_is_transaction_participant(transaction_id));

DROP POLICY IF EXISTS hdc_service_dispute_events_participant_insert
  ON public.hdc_service_dispute_events;
CREATE POLICY hdc_service_dispute_events_participant_insert
ON public.hdc_service_dispute_events
FOR INSERT TO hdc_app
WITH CHECK (
  actor_id = public.hdc_current_user_id() AND
  public.hdc_is_transaction_participant(transaction_id)
);

DROP POLICY IF EXISTS hdc_service_documents_participant_select
  ON public.hdc_service_documents;
CREATE POLICY hdc_service_documents_participant_select
ON public.hdc_service_documents
FOR SELECT TO hdc_app
USING (
  visibility = 'participants' AND
  public.hdc_is_transaction_participant(transaction_id)
);

DROP POLICY IF EXISTS hdc_service_documents_participant_insert
  ON public.hdc_service_documents;
CREATE POLICY hdc_service_documents_participant_insert
ON public.hdc_service_documents
FOR INSERT TO hdc_app
WITH CHECK (
  created_by = public.hdc_current_user_id() AND
  visibility = 'participants' AND
  public.hdc_is_transaction_participant(transaction_id)
);

DROP POLICY IF EXISTS hdc_service_documents_participant_update
  ON public.hdc_service_documents;
CREATE POLICY hdc_service_documents_participant_update
ON public.hdc_service_documents
FOR UPDATE TO hdc_app
USING (
  created_by = public.hdc_current_user_id() AND
  visibility = 'participants' AND
  public.hdc_is_transaction_participant(transaction_id)
)
WITH CHECK (
  created_by = public.hdc_current_user_id() AND
  visibility = 'participants' AND
  public.hdc_is_transaction_participant(transaction_id)
);

GRANT SELECT, INSERT, UPDATE ON public.hdc_service_disputes TO hdc_app;
GRANT SELECT, INSERT ON public.hdc_service_dispute_events TO hdc_app;
GRANT SELECT, INSERT, UPDATE ON public.hdc_service_documents TO hdc_app;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES (
  '0015', 'documents_and_disputes', false
)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = false;

COMMIT;
