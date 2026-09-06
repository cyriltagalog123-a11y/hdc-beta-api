-- HDC post-Build-25 public news and recognition foundation.
-- Public posts are readable by everyone. Creation and modification remain
-- server-authorized for Owner, Super Admin, and Admin accounts only.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0018'
     ) THEN
    RAISE EXCEPTION 'HDC migration 0018 must be applied first';
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.hdc_public_news_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL DEFAULT 'announcement'
    CHECK (kind IN ('announcement', 'feature', 'maintenance', 'recognition')),
  title varchar(160) NOT NULL,
  summary varchar(320) NOT NULL,
  body text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published', 'archived')),
  is_pinned boolean NOT NULL DEFAULT false,
  recognition_subject varchar(160),
  recognition_consent_confirmed boolean NOT NULL DEFAULT false,
  published_at timestamptz,
  created_by uuid NOT NULL REFERENCES public.hdc_users(id),
  updated_by uuid NOT NULL REFERENCES public.hdc_users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_public_news_title_not_blank
    CHECK (length(btrim(title)) BETWEEN 3 AND 160),
  CONSTRAINT hdc_public_news_summary_not_blank
    CHECK (length(btrim(summary)) BETWEEN 3 AND 320),
  CONSTRAINT hdc_public_news_body_not_blank
    CHECK (length(btrim(body)) BETWEEN 3 AND 12000),
  CONSTRAINT hdc_public_news_published_at_required
    CHECK (
      (status = 'published' AND published_at IS NOT NULL)
      OR (status <> 'published')
    ),
  CONSTRAINT hdc_public_news_recognition_consent
    CHECK (
      kind <> 'recognition'
      OR status <> 'published'
      OR (
        recognition_consent_confirmed = true
        AND recognition_subject IS NOT NULL
        AND length(btrim(recognition_subject)) BETWEEN 2 AND 160
      )
    )
);

CREATE INDEX IF NOT EXISTS hdc_public_news_public_feed_idx
  ON public.hdc_public_news_posts (
    is_pinned DESC,
    published_at DESC,
    created_at DESC
  )
  WHERE status = 'published';

CREATE INDEX IF NOT EXISTS hdc_public_news_admin_idx
  ON public.hdc_public_news_posts (status, updated_at DESC);

REVOKE ALL ON public.hdc_public_news_posts FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.hdc_public_news_posts TO hdc_app;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0019', 'public_news_and_recognition', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
