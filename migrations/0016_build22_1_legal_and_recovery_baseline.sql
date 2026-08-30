-- HDC Build 22.1
-- Versioned legal-document integrity, renewed acceptance evidence, privacy
-- request intake, and acknowledgement of the source-controlled auth bootstrap.
-- Apply after migration 0015 on an isolated PostgreSQL branch first.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR to_regclass('public.hdc_terms_acceptances') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0015'
     ) THEN
    RAISE EXCEPTION 'HDC migrations 0000 through 0015 must be applied first';
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.hdc_legal_documents (
  document_type text NOT NULL,
  document_version text NOT NULL,
  title text NOT NULL,
  content_sha256 text NOT NULL,
  public_path text NOT NULL,
  status text NOT NULL DEFAULT 'published',
  effective_at timestamptz NOT NULL,
  published_at timestamptz NOT NULL DEFAULT now(),
  superseded_at timestamptz,
  PRIMARY KEY (document_type, document_version),
  CONSTRAINT hdc_legal_document_type CHECK (
    document_type IN ('terms_of_service', 'privacy_notice')
  ),
  CONSTRAINT hdc_legal_document_version_length
    CHECK (char_length(document_version) BETWEEN 1 AND 40),
  CONSTRAINT hdc_legal_document_title_length
    CHECK (char_length(title) BETWEEN 3 AND 160),
  CONSTRAINT hdc_legal_document_content_sha256
    CHECK (content_sha256 ~ '^[a-f0-9]{64}$'),
  CONSTRAINT hdc_legal_document_public_path
    CHECK (public_path ~ '^/legal/[a-z0-9/_-]+/$'),
  CONSTRAINT hdc_legal_document_status
    CHECK (status IN ('draft', 'published', 'superseded', 'withdrawn')),
  CONSTRAINT hdc_legal_document_lifecycle CHECK (
    (status = 'superseded' AND superseded_at IS NOT NULL)
    OR (status <> 'superseded' AND superseded_at IS NULL)
  )
);

INSERT INTO public.hdc_legal_documents (
  document_type, document_version, title, content_sha256, public_path,
  status, effective_at
) VALUES
  (
    'terms_of_service',
    'beta-2026-08-29',
    'HelpDesk Connect Beta Terms of Service',
    'b4af57360747f1c6c04a9f053c50564c5f49ef735e78f9bf0cfd9c77ffb73e57',
    '/legal/terms/',
    'published',
    '2026-08-29T00:00:00Z'
  ),
  (
    'privacy_notice',
    'beta-2026-08-29',
    'HelpDesk Connect Beta Privacy Notice',
    '3bc1887dca3c4dfc09e79aaad5cf14d717eba46f943dda1fbb2a01434bbfc4bf',
    '/legal/privacy/',
    'published',
    '2026-08-29T00:00:00Z'
  )
ON CONFLICT (document_type, document_version) DO UPDATE SET
  title = EXCLUDED.title,
  content_sha256 = EXCLUDED.content_sha256,
  public_path = EXCLUDED.public_path,
  status = EXCLUDED.status,
  effective_at = EXCLUDED.effective_at,
  superseded_at = NULL;

ALTER TABLE public.hdc_terms_acceptances
  ADD COLUMN IF NOT EXISTS document_content_sha256 text,
  ADD COLUMN IF NOT EXISTS acceptance_method text NOT NULL DEFAULT 'registration';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_terms_acceptance_content_sha256'
      AND conrelid = 'public.hdc_terms_acceptances'::regclass
  ) THEN
    ALTER TABLE public.hdc_terms_acceptances
      ADD CONSTRAINT hdc_terms_acceptance_content_sha256 CHECK (
        document_content_sha256 IS NULL
        OR document_content_sha256 ~ '^[a-f0-9]{64}$'
      );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hdc_terms_acceptance_method'
      AND conrelid = 'public.hdc_terms_acceptances'::regclass
  ) THEN
    ALTER TABLE public.hdc_terms_acceptances
      ADD CONSTRAINT hdc_terms_acceptance_method CHECK (
        acceptance_method IN ('registration', 'renewal', 'administrative')
      );
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.hdc_privacy_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_reference text NOT NULL UNIQUE DEFAULT (
    'HDC-PRV-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
  ),
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  request_type text NOT NULL,
  details text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'submitted',
  version integer NOT NULL DEFAULT 1,
  reviewer_note text NOT NULL DEFAULT '',
  reviewed_by uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  acknowledged_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_privacy_request_public_reference
    CHECK (public_reference ~ '^HDC-PRV-[A-F0-9]{12}$'),
  CONSTRAINT hdc_privacy_request_type CHECK (
    request_type IN (
      'access', 'correction', 'objection', 'export', 'deletion',
      'complaint', 'other'
    )
  ),
  CONSTRAINT hdc_privacy_request_details_length
    CHECK (char_length(details) BETWEEN 10 AND 4000),
  CONSTRAINT hdc_privacy_request_status CHECK (
    status IN ('submitted', 'acknowledged', 'in_review', 'resolved', 'rejected')
  ),
  CONSTRAINT hdc_privacy_request_version CHECK (version >= 1),
  CONSTRAINT hdc_privacy_request_reviewer_note_length
    CHECK (char_length(reviewer_note) <= 4000),
  CONSTRAINT hdc_privacy_request_resolution_state CHECK (
    (status IN ('resolved', 'rejected') AND resolved_at IS NOT NULL)
    OR (status NOT IN ('resolved', 'rejected') AND resolved_at IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS hdc_privacy_requests_user_created_idx
  ON public.hdc_privacy_requests (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS hdc_privacy_requests_review_queue_idx
  ON public.hdc_privacy_requests (status, created_at)
  WHERE status IN ('submitted', 'acknowledged', 'in_review');

DROP TRIGGER IF EXISTS hdc_privacy_requests_touch
  ON public.hdc_privacy_requests;
CREATE TRIGGER hdc_privacy_requests_touch
BEFORE UPDATE ON public.hdc_privacy_requests
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_account_security_row();

ALTER TABLE public.hdc_legal_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_privacy_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hdc_privacy_requests_owner_select
  ON public.hdc_privacy_requests;
CREATE POLICY hdc_privacy_requests_owner_select
ON public.hdc_privacy_requests
FOR SELECT TO hdc_app
USING (user_id = public.hdc_current_user_id());

DROP POLICY IF EXISTS hdc_privacy_requests_owner_insert
  ON public.hdc_privacy_requests;
CREATE POLICY hdc_privacy_requests_owner_insert
ON public.hdc_privacy_requests
FOR INSERT TO hdc_app
WITH CHECK (user_id = public.hdc_current_user_id());

REVOKE ALL ON public.hdc_legal_documents FROM PUBLIC;
REVOKE ALL ON public.hdc_privacy_requests FROM PUBLIC;

GRANT SELECT, INSERT ON public.hdc_privacy_requests TO hdc_app;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES
  ('0000', 'auth_core_bootstrap', true),
  ('0016', 'build22_1_legal_and_recovery_baseline', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
