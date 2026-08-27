-- HDC Build 20
-- Authoritative private messaging for accepted service transactions.
-- Messages remain available across devices while participant authorization,
-- storage choice, and beta quota enforcement stay server-side.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0009'
     )
     OR to_regclass('public.hdc_service_transactions') IS NULL THEN
    RAISE EXCEPTION 'HDC migrations 0001 through 0009 must be applied first';
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.hdc_private_conversations (
  id text PRIMARY KEY,
  transaction_id text NOT NULL UNIQUE
    REFERENCES public.hdc_service_transactions(id) ON DELETE RESTRICT,
  customer_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  storage_mode text NOT NULL DEFAULT 'hdcManaged',
  quota_bytes integer NOT NULL DEFAULT 5242880,
  external_provider_connected boolean NOT NULL DEFAULT false,
  storage_choice_confirmed boolean NOT NULL DEFAULT false,
  external_provider_name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1,
  CONSTRAINT hdc_private_conversations_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_private_conversations_distinct_participants
    CHECK (customer_id <> technician_id),
  CONSTRAINT hdc_private_conversations_storage_mode
    CHECK (storage_mode IN ('hdcManaged', 'userOwned')),
  CONSTRAINT hdc_private_conversations_quota
    CHECK (quota_bytes BETWEEN 65536 AND 1073741824),
  CONSTRAINT hdc_private_conversations_external_provider_name
    CHECK (
      external_provider_name IS NULL OR
      char_length(external_provider_name) BETWEEN 2 AND 100
    )
);

CREATE TABLE IF NOT EXISTS public.hdc_private_messages (
  id text PRIMARY KEY,
  conversation_id text NOT NULL
    REFERENCES public.hdc_private_conversations(id) ON DELETE RESTRICT,
  sender_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  body text NOT NULL,
  status text NOT NULL DEFAULT 'sent',
  language_warning_acknowledged boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz,
  CONSTRAINT hdc_private_messages_id_length
    CHECK (char_length(id) BETWEEN 3 AND 100),
  CONSTRAINT hdc_private_messages_body_length
    CHECK (char_length(body) BETWEEN 1 AND 4000),
  CONSTRAINT hdc_private_messages_status
    CHECK (status IN ('sent', 'delivered', 'read', 'deleted')),
  CONSTRAINT hdc_private_messages_read_state
    CHECK (
      (status = 'read' AND read_at IS NOT NULL) OR
      (status <> 'read')
    )
);

CREATE INDEX IF NOT EXISTS hdc_private_messages_conversation_created_idx
  ON public.hdc_private_messages (conversation_id, created_at, id);

CREATE OR REPLACE FUNCTION public.hdc_validate_private_conversation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  transaction_customer_id uuid;
  transaction_technician_id uuid;
BEGIN
  SELECT customer_id, technician_id
  INTO transaction_customer_id, transaction_technician_id
  FROM public.hdc_service_transactions
  WHERE id = NEW.transaction_id;

  IF transaction_customer_id IS NULL
     OR NEW.customer_id <> transaction_customer_id
     OR NEW.technician_id <> transaction_technician_id THEN
    RAISE EXCEPTION 'Private conversation participants do not match transaction';
  END IF;

  IF TG_OP = 'UPDATE' AND (
    NEW.id <> OLD.id OR
    NEW.transaction_id <> OLD.transaction_id OR
    NEW.customer_id <> OLD.customer_id OR
    NEW.technician_id <> OLD.technician_id OR
    NEW.quota_bytes <> OLD.quota_bytes
  ) THEN
    RAISE EXCEPTION 'Private conversation identity is immutable';
  END IF;

  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_validate_private_conversation() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_private_conversations_validate
  ON public.hdc_private_conversations;
CREATE TRIGGER hdc_private_conversations_validate
BEFORE INSERT OR UPDATE ON public.hdc_private_conversations
FOR EACH ROW EXECUTE FUNCTION public.hdc_validate_private_conversation();

DROP TRIGGER IF EXISTS hdc_private_conversations_touch
  ON public.hdc_private_conversations;
CREATE TRIGGER hdc_private_conversations_touch
BEFORE UPDATE ON public.hdc_private_conversations
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_workflow_row();

CREATE OR REPLACE FUNCTION public.hdc_validate_private_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.hdc_private_conversations conversation_row
    WHERE conversation_row.id = NEW.conversation_id
      AND NEW.sender_id IN (
        conversation_row.customer_id,
        conversation_row.technician_id
      )
  ) THEN
    RAISE EXCEPTION 'Private message sender is not a transaction participant';
  END IF;

  IF TG_OP = 'UPDATE' AND (
    NEW.id <> OLD.id OR
    NEW.conversation_id <> OLD.conversation_id OR
    NEW.sender_id <> OLD.sender_id OR
    NEW.body <> OLD.body OR
    NEW.language_warning_acknowledged <>
      OLD.language_warning_acknowledged OR
    NEW.created_at <> OLD.created_at
  ) THEN
    RAISE EXCEPTION 'Private message content is immutable';
  END IF;

  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_validate_private_message() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_private_messages_validate
  ON public.hdc_private_messages;
CREATE TRIGGER hdc_private_messages_validate
BEFORE INSERT OR UPDATE ON public.hdc_private_messages
FOR EACH ROW EXECUTE FUNCTION public.hdc_validate_private_message();

CREATE OR REPLACE FUNCTION public.hdc_touch_private_conversation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.hdc_private_conversations
  SET updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_touch_private_conversation() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_private_messages_touch_conversation
  ON public.hdc_private_messages;
CREATE TRIGGER hdc_private_messages_touch_conversation
AFTER INSERT OR UPDATE OF status ON public.hdc_private_messages
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_private_conversation();

ALTER TABLE public.hdc_private_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_private_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hdc_private_conversations_select
  ON public.hdc_private_conversations;
CREATE POLICY hdc_private_conversations_select
ON public.hdc_private_conversations
FOR SELECT TO hdc_app
USING (
  public.hdc_current_user_id() IN (customer_id, technician_id)
);

DROP POLICY IF EXISTS hdc_private_conversations_insert
  ON public.hdc_private_conversations;
CREATE POLICY hdc_private_conversations_insert
ON public.hdc_private_conversations
FOR INSERT TO hdc_app
WITH CHECK (
  public.hdc_current_user_id() IN (customer_id, technician_id)
  AND EXISTS (
    SELECT 1
    FROM public.hdc_service_transactions transaction_row
    WHERE transaction_row.id = hdc_private_conversations.transaction_id
      AND transaction_row.customer_id =
        hdc_private_conversations.customer_id
      AND transaction_row.technician_id =
        hdc_private_conversations.technician_id
      AND public.hdc_current_user_id() IN (
        transaction_row.customer_id,
        transaction_row.technician_id
      )
  )
);

DROP POLICY IF EXISTS hdc_private_conversations_update
  ON public.hdc_private_conversations;
CREATE POLICY hdc_private_conversations_update
ON public.hdc_private_conversations
FOR UPDATE TO hdc_app
USING (
  public.hdc_current_user_id() IN (customer_id, technician_id)
)
WITH CHECK (
  public.hdc_current_user_id() IN (customer_id, technician_id)
);

DROP POLICY IF EXISTS hdc_private_messages_select
  ON public.hdc_private_messages;
CREATE POLICY hdc_private_messages_select
ON public.hdc_private_messages
FOR SELECT TO hdc_app
USING (
  EXISTS (
    SELECT 1
    FROM public.hdc_private_conversations conversation_row
    WHERE conversation_row.id = hdc_private_messages.conversation_id
      AND public.hdc_current_user_id() IN (
        conversation_row.customer_id,
        conversation_row.technician_id
      )
  )
);

DROP POLICY IF EXISTS hdc_private_messages_insert
  ON public.hdc_private_messages;
CREATE POLICY hdc_private_messages_insert
ON public.hdc_private_messages
FOR INSERT TO hdc_app
WITH CHECK (
  sender_id = public.hdc_current_user_id()
  AND EXISTS (
    SELECT 1
    FROM public.hdc_private_conversations conversation_row
    WHERE conversation_row.id = hdc_private_messages.conversation_id
      AND public.hdc_current_user_id() IN (
        conversation_row.customer_id,
        conversation_row.technician_id
      )
  )
);

DROP POLICY IF EXISTS hdc_private_messages_update
  ON public.hdc_private_messages;
CREATE POLICY hdc_private_messages_update
ON public.hdc_private_messages
FOR UPDATE TO hdc_app
USING (
  EXISTS (
    SELECT 1
    FROM public.hdc_private_conversations conversation_row
    WHERE conversation_row.id = hdc_private_messages.conversation_id
      AND public.hdc_current_user_id() IN (
        conversation_row.customer_id,
        conversation_row.technician_id
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.hdc_private_conversations conversation_row
    WHERE conversation_row.id = hdc_private_messages.conversation_id
      AND public.hdc_current_user_id() IN (
        conversation_row.customer_id,
        conversation_row.technician_id
      )
  )
);

GRANT SELECT, INSERT, UPDATE
  ON public.hdc_private_conversations,
     public.hdc_private_messages
  TO hdc_app;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES (
  '0010', 'private_transaction_messaging', false
)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = false;

COMMIT;
