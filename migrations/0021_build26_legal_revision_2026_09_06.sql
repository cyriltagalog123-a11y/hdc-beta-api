-- HDC Build 26: publish the material 6 September 2026 legal revision.
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_legal_documents') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0020'
     ) THEN
    RAISE EXCEPTION 'HDC migration 0020 must be applied first';
  END IF;
END
$$;

UPDATE public.hdc_legal_documents
SET status = 'superseded', superseded_at = COALESCE(superseded_at, now())
WHERE document_type IN ('terms_of_service', 'privacy_notice')
  AND document_version <> 'beta-2026-09-06'
  AND status = 'published';

INSERT INTO public.hdc_legal_documents (
  document_type, document_version, title, content_sha256, public_path,
  status, effective_at, superseded_at
) VALUES
  (
    'terms_of_service', 'beta-2026-09-06',
    'HelpDesk Connect Beta Terms of Service',
    'ab71dc81ee05dc8fa865b5261920ea2ebbae05e2b656cfd3d8527ea9062c3720', '/legal/terms/', 'published',
    '2026-09-06T00:00:00Z', NULL
  ),
  (
    'privacy_notice', 'beta-2026-09-06',
    'HelpDesk Connect Beta Privacy Notice',
    '3a349d3b83c1a6f95d5c86533f9b3d41b54d33335b68731cdc8fad34ea42bc93', '/legal/privacy/', 'published',
    '2026-09-06T00:00:00Z', NULL
  )
ON CONFLICT (document_type, document_version) DO UPDATE SET
  title = EXCLUDED.title,
  content_sha256 = EXCLUDED.content_sha256,
  public_path = EXCLUDED.public_path,
  status = EXCLUDED.status,
  effective_at = EXCLUDED.effective_at,
  superseded_at = NULL;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0021', 'build26_legal_revision_2026_09_06', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
