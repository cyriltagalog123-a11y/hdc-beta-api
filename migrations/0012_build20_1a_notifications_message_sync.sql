-- HDC Build 20.1A
-- Idempotent private-message delivery, incremental synchronization metadata,
-- and an unread-notification index for the shared HDC notification center.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0011'
     )
     OR to_regclass('public.hdc_private_messages') IS NULL
     OR to_regclass('public.hdc_notifications') IS NULL THEN
    RAISE EXCEPTION 'HDC migration 0011 and messaging/notification tables are required';
  END IF;
END
$$;

ALTER TABLE public.hdc_private_messages
  ADD COLUMN IF NOT EXISTS client_message_id text,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

UPDATE public.hdc_private_messages
SET
  client_message_id = COALESCE(client_message_id, id),
  updated_at = COALESCE(updated_at, read_at, created_at)
WHERE client_message_id IS NULL OR updated_at IS NULL;

ALTER TABLE public.hdc_private_messages
  ALTER COLUMN client_message_id SET NOT NULL,
  ALTER COLUMN updated_at SET DEFAULT now(),
  ALTER COLUMN updated_at SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'hdc_private_messages_client_id_length'
      AND conrelid = 'public.hdc_private_messages'::regclass
  ) THEN
    ALTER TABLE public.hdc_private_messages
      ADD CONSTRAINT hdc_private_messages_client_id_length
      CHECK (char_length(client_message_id) BETWEEN 3 AND 100);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'hdc_private_messages_client_id_unique'
      AND conrelid = 'public.hdc_private_messages'::regclass
  ) THEN
    ALTER TABLE public.hdc_private_messages
      ADD CONSTRAINT hdc_private_messages_client_id_unique
      UNIQUE (conversation_id, sender_id, client_message_id);
  END IF;
END
$$;

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
    NEW.client_message_id <> OLD.client_message_id OR
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

CREATE OR REPLACE FUNCTION public.hdc_touch_private_message()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_touch_private_message() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_private_messages_touch
  ON public.hdc_private_messages;
CREATE TRIGGER hdc_private_messages_touch
BEFORE UPDATE OF status, read_at ON public.hdc_private_messages
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_private_message();

CREATE INDEX IF NOT EXISTS hdc_private_messages_conversation_updated_idx
  ON public.hdc_private_messages (conversation_id, updated_at, id);

CREATE INDEX IF NOT EXISTS hdc_notifications_user_unread_idx
  ON public.hdc_notifications (user_id, created_at DESC)
  WHERE read_at IS NULL;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES (
  '0012', 'build20_1a_notifications_message_sync', false
)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = false;

COMMIT;
