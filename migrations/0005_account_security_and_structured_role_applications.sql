-- HDC Build 12
-- Account recovery, public member identifiers, structured public-role
-- applications, explicit private review grants, terms evidence, and
-- organization membership. Apply after migration 0004.
-- Test on an isolated Neon branch before production promotion.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_users') IS NULL
     OR to_regclass('public.hdc_platform_role_applications') IS NULL THEN
    RAISE EXCEPTION 'HDC migrations 0001 through 0004 must be applied first';
  END IF;
END
$$;

-- Public-facing IDs are deliberately separate from authentication UUIDs.
ALTER TABLE public.hdc_users
  ADD COLUMN IF NOT EXISTS public_member_id text;

UPDATE public.hdc_users
SET public_member_id = 'HDC-' || upper(substr(replace(id::text, '-', ''), 1, 12))
WHERE public_member_id IS NULL;

ALTER TABLE public.hdc_users
  ALTER COLUMN public_member_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS hdc_users_public_member_id_key
  ON public.hdc_users (public_member_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_users_public_member_id_format'
      AND conrelid = 'public.hdc_users'::regclass
  ) THEN
    ALTER TABLE public.hdc_users
      ADD CONSTRAINT hdc_users_public_member_id_format
      CHECK (public_member_id ~ '^HDC-[A-F0-9]{12}$');
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.hdc_assign_public_member_id()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.public_member_id IS NULL OR NEW.public_member_id = '' THEN
    NEW.public_member_id :=
      'HDC-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_assign_public_member_id() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_users_assign_public_member_id ON public.hdc_users;
CREATE TRIGGER hdc_users_assign_public_member_id
BEFORE INSERT ON public.hdc_users
FOR EACH ROW EXECUTE FUNCTION public.hdc_assign_public_member_id();

-- Recovery answers are never stored in plaintext. The API supplies a
-- server-peppered bcrypt hash and never reads these rows into public views.
CREATE TABLE IF NOT EXISTS public.hdc_account_recovery_answers (
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  question_version smallint NOT NULL DEFAULT 1,
  question_code text NOT NULL,
  answer_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, question_code),
  CONSTRAINT hdc_account_recovery_question_version CHECK (question_version > 0),
  CONSTRAINT hdc_account_recovery_question_code CHECK (
    question_code IN ('first_meal', 'childhood_nickname', 'private_phrase')
  ),
  CONSTRAINT hdc_account_recovery_answer_hash_length
    CHECK (char_length(answer_hash) BETWEEN 50 AND 200)
);

CREATE TABLE IF NOT EXISTS public.hdc_password_reset_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  token_digest text NOT NULL UNIQUE,
  source text NOT NULL DEFAULT 'security_questions',
  status text NOT NULL DEFAULT 'pending',
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  issued_by uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  issued_reason text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_password_reset_token_digest_v2
    CHECK (token_digest ~ '^[a-f0-9]{64}$')
);

-- The live beta already has the owner-issued reset-token foundation. Upgrade
-- it in place without invalidating or duplicating existing one-time links.
ALTER TABLE public.hdc_password_reset_tokens
  ADD COLUMN IF NOT EXISTS source text,
  ADD COLUMN IF NOT EXISTS status text;

UPDATE public.hdc_password_reset_tokens
SET source = COALESCE(source, 'owner_initiated'),
    status = COALESCE(
      status,
      CASE WHEN consumed_at IS NULL THEN 'pending' ELSE 'consumed' END
    )
WHERE source IS NULL OR status IS NULL;

ALTER TABLE public.hdc_password_reset_tokens
  ALTER COLUMN source SET DEFAULT 'security_questions',
  ALTER COLUMN source SET NOT NULL,
  ALTER COLUMN status SET DEFAULT 'pending',
  ALTER COLUMN status SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_password_reset_token_source'
      AND conrelid = 'public.hdc_password_reset_tokens'::regclass
  ) THEN
    ALTER TABLE public.hdc_password_reset_tokens
      ADD CONSTRAINT hdc_password_reset_token_source CHECK (
        source IN ('security_questions', 'manual_review', 'owner_initiated')
      );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_password_reset_token_status'
      AND conrelid = 'public.hdc_password_reset_tokens'::regclass
  ) THEN
    ALTER TABLE public.hdc_password_reset_tokens
      ADD CONSTRAINT hdc_password_reset_token_status CHECK (
        status IN ('pending', 'consumed', 'revoked')
      );
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS hdc_password_reset_tokens_active_idx
  ON public.hdc_password_reset_tokens (user_id, expires_at DESC)
  WHERE status = 'pending' AND consumed_at IS NULL;

CREATE TABLE IF NOT EXISTS public.hdc_account_recovery_review_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  identity_fingerprint text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  delivery_status text NOT NULL DEFAULT 'pending_configuration',
  review_email_snapshot text,
  reviewed_by uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  reviewer_note text NOT NULL DEFAULT '',
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_account_recovery_review_status
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  CONSTRAINT hdc_account_recovery_delivery_status CHECK (
    delivery_status IN (
      'pending_configuration', 'queued', 'sent', 'failed', 'not_required'
    )
  ),
  CONSTRAINT hdc_account_recovery_review_note_length
    CHECK (char_length(reviewer_note) <= 2000)
);

CREATE UNIQUE INDEX IF NOT EXISTS hdc_account_recovery_one_pending_idx
  ON public.hdc_account_recovery_review_requests (user_id)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS hdc_account_recovery_review_queue_idx
  ON public.hdc_account_recovery_review_requests (status, created_at);

-- Provider-neutral queue. A later verified email provider may consume these
-- records without changing the account recovery contract.
CREATE TABLE IF NOT EXISTS public.hdc_security_delivery_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  purpose text NOT NULL,
  recipient text NOT NULL,
  subject text NOT NULL,
  body_text text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued',
  attempt_count integer NOT NULL DEFAULT 0,
  last_error text NOT NULL DEFAULT '',
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_security_delivery_purpose CHECK (
    purpose IN ('manual_recovery_review', 'password_reset')
  ),
  CONSTRAINT hdc_security_delivery_status CHECK (
    status IN ('queued', 'sending', 'sent', 'failed', 'cancelled')
  ),
  CONSTRAINT hdc_security_delivery_attempt_count CHECK (attempt_count >= 0),
  CONSTRAINT hdc_security_delivery_metadata_object
    CHECK (jsonb_typeof(metadata) = 'object')
);

-- Existing free-text applications remain readable. New submissions use the
-- versioned private answers object and an immutable applicant snapshot.
ALTER TABLE public.hdc_platform_role_applications
  ADD COLUMN IF NOT EXISTS form_version integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS answers jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS applicant_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS submitted_at timestamptz,
  ADD COLUMN IF NOT EXISTS changes_requested_at timestamptz;

ALTER TABLE public.hdc_platform_role_applications
  DROP CONSTRAINT IF EXISTS hdc_platform_role_application_status,
  DROP CONSTRAINT IF EXISTS hdc_platform_role_review_state;

UPDATE public.hdc_platform_role_applications
SET status = 'submitted',
    submitted_at = COALESCE(submitted_at, created_at)
WHERE status = 'pending';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_platform_role_application_status_v2'
      AND conrelid = 'public.hdc_platform_role_applications'::regclass
  ) THEN
    ALTER TABLE public.hdc_platform_role_applications
      ADD CONSTRAINT hdc_platform_role_application_status_v2 CHECK (
        status IN (
          'submitted', 'under_review', 'changes_requested',
          'approved', 'rejected', 'withdrawn'
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_platform_role_application_answers_object'
      AND conrelid = 'public.hdc_platform_role_applications'::regclass
  ) THEN
    ALTER TABLE public.hdc_platform_role_applications
      ADD CONSTRAINT hdc_platform_role_application_answers_object
      CHECK (jsonb_typeof(answers) = 'object');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_platform_role_application_snapshot_object'
      AND conrelid = 'public.hdc_platform_role_applications'::regclass
  ) THEN
    ALTER TABLE public.hdc_platform_role_applications
      ADD CONSTRAINT hdc_platform_role_application_snapshot_object
      CHECK (jsonb_typeof(applicant_snapshot) = 'object');
  END IF;
END
$$;

DROP INDEX IF EXISTS public.hdc_platform_role_application_pending_unique;
CREATE UNIQUE INDEX IF NOT EXISTS hdc_platform_role_application_active_unique
  ON public.hdc_platform_role_applications (user_id, role)
  WHERE status IN ('submitted', 'under_review');

-- Explicit grants let an authorized internal account review only the public
-- role categories assigned to it. Owner and Super Admin retain implicit scope.
CREATE TABLE IF NOT EXISTS public.hdc_internal_permission_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  permission_code text NOT NULL,
  role_scope text,
  is_active boolean NOT NULL DEFAULT true,
  granted_by uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  assignment_note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_internal_permission_unique
    UNIQUE NULLS NOT DISTINCT (user_id, permission_code, role_scope),
  CONSTRAINT hdc_internal_permission_code CHECK (
    permission_code IN ('platform_roles.review', 'account_recovery.review')
  ),
  CONSTRAINT hdc_internal_permission_role_scope CHECK (
    role_scope IS NULL OR role_scope IN (
      'technician', 'business', 'seller', 'supplier', 'store'
    )
  ),
  CONSTRAINT hdc_internal_permission_note_length
    CHECK (char_length(assignment_note) <= 1000)
);

-- Public role grants have their own lifecycle and provenance. is_active is
-- retained for compatibility with the current client contract.
ALTER TABLE public.hdc_user_roles
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS source_application_id uuid
    REFERENCES public.hdc_platform_role_applications(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS granted_by uuid
    REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS granted_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS suspended_at timestamptz,
  ADD COLUMN IF NOT EXISTS revoked_at timestamptz,
  ADD COLUMN IF NOT EXISTS lifecycle_note text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_user_roles_lifecycle_status'
      AND conrelid = 'public.hdc_user_roles'::regclass
  ) THEN
    ALTER TABLE public.hdc_user_roles
      ADD CONSTRAINT hdc_user_roles_lifecycle_status
      CHECK (status IN ('active', 'suspended', 'revoked'));
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.hdc_terms_acceptances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  document_type text NOT NULL,
  document_version text NOT NULL,
  accepted_at timestamptz NOT NULL DEFAULT now(),
  client_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT hdc_terms_acceptance_unique
    UNIQUE (user_id, document_type, document_version),
  CONSTRAINT hdc_terms_document_type
    CHECK (document_type IN ('terms_of_service', 'privacy_notice')),
  CONSTRAINT hdc_terms_document_version_length
    CHECK (char_length(document_version) BETWEEN 1 AND 40),
  CONSTRAINT hdc_terms_client_metadata_object
    CHECK (jsonb_typeof(client_metadata) = 'object')
);

ALTER TABLE public.hdc_auth_sessions
  ADD COLUMN IF NOT EXISTS device_label text;

-- Organizations never own credentials. Every person keeps an individual UUID
-- and receives an explicit membership in a business or store organization.
CREATE TABLE IF NOT EXISTS public.hdc_organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id text NOT NULL UNIQUE,
  owner_user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  legal_name text NOT NULL,
  display_name text NOT NULL,
  organization_type text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_organization_public_id_format
    CHECK (public_id ~ '^ORG-[A-F0-9]{12}$'),
  CONSTRAINT hdc_organization_legal_name_length
    CHECK (char_length(legal_name) BETWEEN 2 AND 200),
  CONSTRAINT hdc_organization_display_name_length
    CHECK (char_length(display_name) BETWEEN 2 AND 160),
  CONSTRAINT hdc_organization_type
    CHECK (organization_type IN ('business', 'seller', 'supplier', 'store')),
  CONSTRAINT hdc_organization_status
    CHECK (status IN ('active', 'suspended', 'closed'))
);

CREATE TABLE IF NOT EXISTS public.hdc_organization_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL
    REFERENCES public.hdc_organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  membership_role text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  invited_by uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  accepted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_organization_membership_unique
    UNIQUE (organization_id, user_id),
  CONSTRAINT hdc_organization_membership_role CHECK (
    membership_role IN (
      'owner', 'manager', 'dispatcher', 'technician',
      'inventory', 'sales', 'viewer'
    )
  ),
  CONSTRAINT hdc_organization_membership_status
    CHECK (status IN ('invited', 'active', 'suspended', 'revoked'))
);

CREATE INDEX IF NOT EXISTS hdc_organization_memberships_user_idx
  ON public.hdc_organization_memberships (user_id, status);

CREATE TABLE IF NOT EXISTS public.hdc_store_branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL
    REFERENCES public.hdc_organizations(id) ON DELETE CASCADE,
  branch_code text NOT NULL,
  name text NOT NULL,
  address text NOT NULL,
  hours jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_store_branch_unique UNIQUE (organization_id, branch_code),
  CONSTRAINT hdc_store_branch_code
    CHECK (branch_code ~ '^[A-Za-z0-9_-]{2,40}$'),
  CONSTRAINT hdc_store_branch_name_length
    CHECK (char_length(name) BETWEEN 2 AND 160),
  CONSTRAINT hdc_store_branch_address_length
    CHECK (char_length(address) BETWEEN 5 AND 300),
  CONSTRAINT hdc_store_branch_hours_object CHECK (jsonb_typeof(hours) = 'object'),
  CONSTRAINT hdc_store_branch_status
    CHECK (status IN ('active', 'suspended', 'closed'))
);

CREATE OR REPLACE FUNCTION public.hdc_touch_account_security_row()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_touch_account_security_row() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_recovery_answers_touch
  ON public.hdc_account_recovery_answers;
CREATE TRIGGER hdc_recovery_answers_touch
BEFORE UPDATE ON public.hdc_account_recovery_answers
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

DROP TRIGGER IF EXISTS hdc_recovery_review_touch
  ON public.hdc_account_recovery_review_requests;
CREATE TRIGGER hdc_recovery_review_touch
BEFORE UPDATE ON public.hdc_account_recovery_review_requests
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

DROP TRIGGER IF EXISTS hdc_security_delivery_touch
  ON public.hdc_security_delivery_outbox;
CREATE TRIGGER hdc_security_delivery_touch
BEFORE UPDATE ON public.hdc_security_delivery_outbox
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

DROP TRIGGER IF EXISTS hdc_internal_permission_grants_touch
  ON public.hdc_internal_permission_grants;
CREATE TRIGGER hdc_internal_permission_grants_touch
BEFORE UPDATE ON public.hdc_internal_permission_grants
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

DROP TRIGGER IF EXISTS hdc_user_roles_lifecycle_touch
  ON public.hdc_user_roles;
CREATE TRIGGER hdc_user_roles_lifecycle_touch
BEFORE UPDATE ON public.hdc_user_roles
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

DROP TRIGGER IF EXISTS hdc_organizations_touch ON public.hdc_organizations;
CREATE TRIGGER hdc_organizations_touch
BEFORE UPDATE ON public.hdc_organizations
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

DROP TRIGGER IF EXISTS hdc_organization_memberships_touch
  ON public.hdc_organization_memberships;
CREATE TRIGGER hdc_organization_memberships_touch
BEFORE UPDATE ON public.hdc_organization_memberships
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

DROP TRIGGER IF EXISTS hdc_store_branches_touch ON public.hdc_store_branches;
CREATE TRIGGER hdc_store_branches_touch
BEFORE UPDATE ON public.hdc_store_branches
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

ALTER TABLE public.hdc_account_recovery_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_password_reset_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_account_recovery_review_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_security_delivery_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_internal_permission_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_terms_acceptances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_organization_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_store_branches ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.hdc_account_recovery_answers FROM PUBLIC;
REVOKE ALL ON public.hdc_password_reset_tokens FROM PUBLIC;
REVOKE ALL ON public.hdc_account_recovery_review_requests FROM PUBLIC;
REVOKE ALL ON public.hdc_security_delivery_outbox FROM PUBLIC;
REVOKE ALL ON public.hdc_internal_permission_grants FROM PUBLIC;
REVOKE ALL ON public.hdc_terms_acceptances FROM PUBLIC;
REVOKE ALL ON public.hdc_organizations FROM PUBLIC;
REVOKE ALL ON public.hdc_organization_memberships FROM PUBLIC;
REVOKE ALL ON public.hdc_store_branches FROM PUBLIC;

COMMIT;
