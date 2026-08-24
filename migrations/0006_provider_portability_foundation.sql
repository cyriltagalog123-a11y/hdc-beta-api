-- HDC Build 13
-- Provider portability, migration ledger, external-reference isolation,
-- delivery-worker leases, and recovery-pepper key rotation.
-- Apply after migration 0005 on an isolated PostgreSQL branch first.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_users') IS NULL
     OR to_regclass('public.hdc_account_recovery_answers') IS NULL
     OR to_regclass('public.hdc_security_delivery_outbox') IS NULL THEN
    RAISE EXCEPTION 'HDC migrations 0001 through 0005 must be applied first';
  END IF;
END
$$;

-- This ledger gives future migration runners an HDC-owned source of truth.
-- Versions 0001-0005 are recorded as a baseline because they predate it.
CREATE TABLE IF NOT EXISTS public.hdc_schema_migrations (
  version text PRIMARY KEY,
  migration_name text NOT NULL,
  checksum_sha256 text,
  is_baseline boolean NOT NULL DEFAULT false,
  applied_by text NOT NULL DEFAULT current_user,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_schema_migration_version
    CHECK (version ~ '^[0-9]{4}$'),
  CONSTRAINT hdc_schema_migration_name_length
    CHECK (char_length(migration_name) BETWEEN 3 AND 160),
  CONSTRAINT hdc_schema_migration_checksum CHECK (
    checksum_sha256 IS NULL OR checksum_sha256 ~ '^[a-f0-9]{64}$'
  )
);

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES
  ('0001', 'active_neon_auth_contract', true),
  ('0002', 'workflow_authority', true),
  ('0003', 'role_domain_separation', true),
  ('0004', 'one_account_role_profiles', true),
  ('0005', 'account_security_and_structured_role_applications', true),
  ('0006', 'provider_portability_foundation', false)
ON CONFLICT (version) DO NOTHING;

-- Recovery answers identify which server-only pepper produced their bcrypt
-- input. Existing rows remain on the legacy key until the member replaces
-- their answers; plaintext answers are never required for rotation.
ALTER TABLE public.hdc_account_recovery_answers
  ADD COLUMN IF NOT EXISTS pepper_key_id text;

UPDATE public.hdc_account_recovery_answers
SET pepper_key_id = 'legacy-session-v1'
WHERE pepper_key_id IS NULL OR pepper_key_id = '';

ALTER TABLE public.hdc_account_recovery_answers
  ALTER COLUMN pepper_key_id SET DEFAULT 'legacy-session-v1',
  ALTER COLUMN pepper_key_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_recovery_answer_pepper_key_id'
      AND conrelid = 'public.hdc_account_recovery_answers'::regclass
  ) THEN
    ALTER TABLE public.hdc_account_recovery_answers
      ADD CONSTRAINT hdc_recovery_answer_pepper_key_id
      CHECK (pepper_key_id ~ '^[a-z][a-z0-9_-]{2,63}$');
  END IF;
END
$$;

-- Delivery is queued before any email/SMS adapter is invoked. Worker leases,
-- retry timing, and provider receipts keep provider outages from blocking the
-- account operation that produced the message.
ALTER TABLE public.hdc_security_delivery_outbox
  ADD COLUMN IF NOT EXISTS channel text,
  ADD COLUMN IF NOT EXISTS provider_key text,
  ADD COLUMN IF NOT EXISTS external_delivery_id text,
  ADD COLUMN IF NOT EXISTS idempotency_key uuid,
  ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_attempt_at timestamptz,
  ADD COLUMN IF NOT EXISTS locked_at timestamptz,
  ADD COLUMN IF NOT EXISTS locked_by text;

UPDATE public.hdc_security_delivery_outbox
SET channel = COALESCE(channel, 'email'),
    idempotency_key = COALESCE(idempotency_key, gen_random_uuid()),
    next_attempt_at = COALESCE(next_attempt_at, created_at)
WHERE channel IS NULL
   OR idempotency_key IS NULL
   OR next_attempt_at IS NULL;

ALTER TABLE public.hdc_security_delivery_outbox
  ALTER COLUMN channel SET DEFAULT 'email',
  ALTER COLUMN channel SET NOT NULL,
  ALTER COLUMN idempotency_key SET DEFAULT gen_random_uuid(),
  ALTER COLUMN idempotency_key SET NOT NULL,
  ALTER COLUMN next_attempt_at SET DEFAULT now(),
  ALTER COLUMN next_attempt_at SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_security_delivery_channel'
      AND conrelid = 'public.hdc_security_delivery_outbox'::regclass
  ) THEN
    ALTER TABLE public.hdc_security_delivery_outbox
      ADD CONSTRAINT hdc_security_delivery_channel
      CHECK (channel IN ('email', 'sms'));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_security_delivery_provider_key'
      AND conrelid = 'public.hdc_security_delivery_outbox'::regclass
  ) THEN
    ALTER TABLE public.hdc_security_delivery_outbox
      ADD CONSTRAINT hdc_security_delivery_provider_key CHECK (
        provider_key IS NULL OR provider_key ~ '^[a-z][a-z0-9_-]{1,47}$'
      );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_security_delivery_lock_owner'
      AND conrelid = 'public.hdc_security_delivery_outbox'::regclass
  ) THEN
    ALTER TABLE public.hdc_security_delivery_outbox
      ADD CONSTRAINT hdc_security_delivery_lock_owner CHECK (
        locked_by IS NULL OR char_length(locked_by) BETWEEN 1 AND 120
      );
  END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS hdc_security_delivery_idempotency_key
  ON public.hdc_security_delivery_outbox (idempotency_key);

CREATE INDEX IF NOT EXISTS hdc_security_delivery_worker_queue
  ON public.hdc_security_delivery_outbox (channel, status, next_attempt_at)
  WHERE status IN ('queued', 'failed');

-- External provider identifiers never become HDC entity IDs. This private
-- mapping permits provider replacement while keeping immutable HDC IDs and
-- historical links stable. Metadata is explicitly non-secret.
CREATE TABLE IF NOT EXISTS public.hdc_external_provider_references (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_type text NOT NULL,
  provider_key text NOT NULL,
  internal_entity_type text NOT NULL,
  internal_entity_id text NOT NULL,
  external_reference text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  migrated_from_id uuid REFERENCES public.hdc_external_provider_references(id)
    ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_external_provider_service_type CHECK (
    service_type IN (
      'email', 'sms', 'phone_verification', 'object_storage', 'payment'
    )
  ),
  CONSTRAINT hdc_external_provider_key
    CHECK (provider_key ~ '^[a-z][a-z0-9_-]{1,47}$'),
  CONSTRAINT hdc_external_provider_entity_type
    CHECK (internal_entity_type ~ '^[a-z][a-z0-9_.-]{1,79}$'),
  CONSTRAINT hdc_external_provider_entity_id_length
    CHECK (char_length(internal_entity_id) BETWEEN 1 AND 160),
  CONSTRAINT hdc_external_provider_reference_length
    CHECK (char_length(external_reference) BETWEEN 1 AND 500),
  CONSTRAINT hdc_external_provider_metadata_object
    CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT hdc_external_provider_metadata_no_secrets CHECK (
    NOT metadata ?| ARRAY[
      'apiKey', 'api_key', 'secret', 'token', 'password',
      'connectionString', 'connection_string', 'privateKey', 'private_key'
    ]
  ),
  CONSTRAINT hdc_external_provider_reference_unique
    UNIQUE (service_type, provider_key, external_reference)
);

CREATE INDEX IF NOT EXISTS hdc_external_provider_internal_lookup
  ON public.hdc_external_provider_references (
    service_type, internal_entity_type, internal_entity_id, is_active
  );

-- User and organization storage choice is an HDC-owned binding. Credentials
-- are held by a secret service and represented here only by an opaque,
-- non-secret reference. No provider token belongs in this table.
CREATE TABLE IF NOT EXISTS public.hdc_storage_bindings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  organization_id uuid REFERENCES public.hdc_organizations(id) ON DELETE CASCADE,
  ownership_mode text NOT NULL,
  provider_key text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  credential_reference text,
  quota_bytes bigint NOT NULL DEFAULT 0,
  used_bytes bigint NOT NULL DEFAULT 0,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_storage_binding_ownership_mode CHECK (
    ownership_mode IN ('hdc_managed', 'user_owned', 'organization_owned')
  ),
  CONSTRAINT hdc_storage_binding_provider_key
    CHECK (provider_key ~ '^[a-z][a-z0-9_-]{1,47}$'),
  CONSTRAINT hdc_storage_binding_status
    CHECK (status IN ('pending', 'active', 'degraded', 'revoked')),
  CONSTRAINT hdc_storage_binding_credential_reference CHECK (
    credential_reference IS NULL
    OR char_length(credential_reference) BETWEEN 3 AND 240
  ),
  CONSTRAINT hdc_storage_binding_usage
    CHECK (quota_bytes >= 0 AND used_bytes >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS hdc_storage_binding_one_primary
  ON public.hdc_storage_bindings (
    owner_user_id,
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  WHERE is_primary = true AND status IN ('pending', 'active', 'degraded');

CREATE INDEX IF NOT EXISTS hdc_storage_binding_owner_lookup
  ON public.hdc_storage_bindings (owner_user_id, organization_id, status);

CREATE TABLE IF NOT EXISTS public.hdc_storage_migrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key uuid NOT NULL DEFAULT gen_random_uuid(),
  source_binding_id uuid NOT NULL
    REFERENCES public.hdc_storage_bindings(id) ON DELETE RESTRICT,
  destination_binding_id uuid NOT NULL
    REFERENCES public.hdc_storage_bindings(id) ON DELETE RESTRICT,
  scope text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  requested_by_user_id uuid NOT NULL
    REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  copied_objects bigint NOT NULL DEFAULT 0,
  copied_bytes bigint NOT NULL DEFAULT 0,
  checkpoint jsonb NOT NULL DEFAULT '{}'::jsonb,
  attempt_count integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  locked_at timestamptz,
  locked_by text,
  manifest_sha256 text,
  error_code text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_storage_migration_distinct_bindings
    CHECK (source_binding_id <> destination_binding_id),
  CONSTRAINT hdc_storage_migration_scope CHECK (
    scope IN ('attachments', 'private_messages', 'exports', 'all')
  ),
  CONSTRAINT hdc_storage_migration_status CHECK (
    status IN ('pending', 'running', 'completed', 'failed', 'cancelled')
  ),
  CONSTRAINT hdc_storage_migration_counts
    CHECK (
      copied_objects >= 0 AND copied_bytes >= 0 AND attempt_count >= 0
    ),
  CONSTRAINT hdc_storage_migration_checkpoint
    CHECK (jsonb_typeof(checkpoint) = 'object'),
  CONSTRAINT hdc_storage_migration_lock_owner CHECK (
    locked_by IS NULL OR char_length(locked_by) BETWEEN 1 AND 120
  ),
  CONSTRAINT hdc_storage_migration_manifest CHECK (
    manifest_sha256 IS NULL OR manifest_sha256 ~ '^[a-f0-9]{64}$'
  ),
  CONSTRAINT hdc_storage_migration_error_code CHECK (
    error_code IS NULL OR error_code ~ '^[a-z][a-z0-9_.-]{1,79}$'
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS hdc_storage_migration_idempotency
  ON public.hdc_storage_migrations (idempotency_key);

CREATE INDEX IF NOT EXISTS hdc_storage_migration_queue
  ON public.hdc_storage_migrations (status, next_attempt_at, created_at)
  WHERE status IN ('pending', 'running');

-- Export manifests provide a durable, provider-neutral handoff for account,
-- organization, and full-platform portability. The exported object itself is
-- referenced through the private external-provider mapping above.
CREATE TABLE IF NOT EXISTS public.hdc_data_exports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schema_version text NOT NULL,
  scope_kind text NOT NULL,
  scope_entity_id text NOT NULL,
  requested_by_user_id uuid NOT NULL
    REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'pending',
  object_reference_id uuid
    REFERENCES public.hdc_external_provider_references(id) ON DELETE SET NULL,
  manifest_sha256 text,
  record_count bigint NOT NULL DEFAULT 0,
  byte_count bigint NOT NULL DEFAULT 0,
  failure_code text,
  completed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_data_export_schema_version
    CHECK (schema_version ~ '^[a-z0-9][a-z0-9_.-]{0,39}$'),
  CONSTRAINT hdc_data_export_scope_kind
    CHECK (scope_kind IN ('member', 'organization', 'platform')),
  CONSTRAINT hdc_data_export_scope_entity_id
    CHECK (char_length(scope_entity_id) BETWEEN 1 AND 160),
  CONSTRAINT hdc_data_export_status CHECK (
    status IN ('pending', 'running', 'completed', 'failed', 'expired')
  ),
  CONSTRAINT hdc_data_export_counts
    CHECK (record_count >= 0 AND byte_count >= 0),
  CONSTRAINT hdc_data_export_manifest CHECK (
    manifest_sha256 IS NULL OR manifest_sha256 ~ '^[a-f0-9]{64}$'
  ),
  CONSTRAINT hdc_data_export_failure_code CHECK (
    failure_code IS NULL OR failure_code ~ '^[a-z][a-z0-9_.-]{1,79}$'
  ),
  CONSTRAINT hdc_data_export_completed_material CHECK (
    status <> 'completed'
    OR (
      object_reference_id IS NOT NULL
      AND manifest_sha256 IS NOT NULL
      AND completed_at IS NOT NULL
    )
  )
);

CREATE INDEX IF NOT EXISTS hdc_data_export_requester_lookup
  ON public.hdc_data_exports (requested_by_user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS hdc_data_export_worker_queue
  ON public.hdc_data_exports (status, created_at)
  WHERE status IN ('pending', 'running');

DROP TRIGGER IF EXISTS hdc_external_provider_references_touch
  ON public.hdc_external_provider_references;
CREATE TRIGGER hdc_external_provider_references_touch
BEFORE UPDATE ON public.hdc_external_provider_references
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

DROP TRIGGER IF EXISTS hdc_storage_bindings_touch
  ON public.hdc_storage_bindings;
CREATE TRIGGER hdc_storage_bindings_touch
BEFORE UPDATE ON public.hdc_storage_bindings
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

DROP TRIGGER IF EXISTS hdc_storage_migrations_touch
  ON public.hdc_storage_migrations;
CREATE TRIGGER hdc_storage_migrations_touch
BEFORE UPDATE ON public.hdc_storage_migrations
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

DROP TRIGGER IF EXISTS hdc_data_exports_touch
  ON public.hdc_data_exports;
CREATE TRIGGER hdc_data_exports_touch
BEFORE UPDATE ON public.hdc_data_exports
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

ALTER TABLE public.hdc_schema_migrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_external_provider_references ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_storage_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_storage_migrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_data_exports ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.hdc_schema_migrations FROM PUBLIC;
REVOKE ALL ON public.hdc_external_provider_references FROM PUBLIC;
REVOKE ALL ON public.hdc_storage_bindings FROM PUBLIC;
REVOKE ALL ON public.hdc_storage_migrations FROM PUBLIC;
REVOKE ALL ON public.hdc_data_exports FROM PUBLIC;

COMMENT ON TABLE public.hdc_external_provider_references IS
  'Private non-secret mapping between immutable HDC IDs and replaceable provider IDs.';
COMMENT ON COLUMN public.hdc_external_provider_references.metadata IS
  'Non-secret portability metadata only. Provider credentials remain in the runtime secret store.';
COMMENT ON COLUMN public.hdc_storage_bindings.credential_reference IS
  'Opaque non-secret reference to credentials held by an authorized secret service.';
COMMENT ON TABLE public.hdc_data_exports IS
  'Private export jobs and integrity manifests for provider-neutral HDC data portability.';

COMMIT;
