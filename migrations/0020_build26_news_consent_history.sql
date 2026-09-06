-- HDC Build 26: durable public-news history and recognition-consent evidence.
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_public_news_posts') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0019'
     ) THEN
    RAISE EXCEPTION 'HDC migration 0019 must be applied first';
  END IF;
END
$$;

ALTER TABLE public.hdc_public_news_posts
  ADD COLUMN IF NOT EXISTS recognition_consent_at timestamptz,
  ADD COLUMN IF NOT EXISTS recognition_consent_method text,
  ADD COLUMN IF NOT EXISTS recognition_consent_scope varchar(500),
  ADD COLUMN IF NOT EXISTS recognition_consent_reference varchar(500),
  ADD COLUMN IF NOT EXISTS ever_published boolean NOT NULL DEFAULT false;

UPDATE public.hdc_public_news_posts
SET
  ever_published = true,
  recognition_consent_at = CASE
    WHEN kind = 'recognition' AND recognition_consent_confirmed = true
      THEN COALESCE(recognition_consent_at, published_at, created_at)
    ELSE recognition_consent_at
  END,
  recognition_consent_method = CASE
    WHEN kind = 'recognition' AND recognition_consent_confirmed = true
      THEN COALESCE(recognition_consent_method, 'legacy_confirmation')
    ELSE recognition_consent_method
  END,
  recognition_consent_scope = CASE
    WHEN kind = 'recognition' AND recognition_consent_confirmed = true
      THEN COALESCE(recognition_consent_scope, 'Public HDC News recognition')
    ELSE recognition_consent_scope
  END,
  recognition_consent_reference = CASE
    WHEN kind = 'recognition' AND recognition_consent_confirmed = true
      THEN COALESCE(recognition_consent_reference, 'Migrated from Build 25 consent confirmation')
    ELSE recognition_consent_reference
  END
WHERE published_at IS NOT NULL OR recognition_consent_confirmed = true;

ALTER TABLE public.hdc_public_news_posts
  DROP CONSTRAINT IF EXISTS hdc_public_news_recognition_consent_evidence;
ALTER TABLE public.hdc_public_news_posts
  ADD CONSTRAINT hdc_public_news_recognition_consent_evidence CHECK (
    kind <> 'recognition'
    OR status <> 'published'
    OR (
      recognition_consent_confirmed = true
      AND recognition_consent_at IS NOT NULL
      AND recognition_consent_method IS NOT NULL
      AND length(btrim(recognition_consent_method)) BETWEEN 2 AND 40
      AND recognition_consent_scope IS NOT NULL
      AND length(btrim(recognition_consent_scope)) BETWEEN 3 AND 500
    )
  );

ALTER TABLE public.hdc_public_news_posts
  DROP CONSTRAINT IF EXISTS hdc_public_news_recognition_consent_method;
ALTER TABLE public.hdc_public_news_posts
  ADD CONSTRAINT hdc_public_news_recognition_consent_method CHECK (
    recognition_consent_method IS NULL
    OR recognition_consent_method IN (
      'email', 'written_message', 'platform_message', 'other',
      'legacy_confirmation'
    )
  );

CREATE OR REPLACE FUNCTION public.hdc_public_news_lifecycle_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.ever_published = true OR OLD.published_at IS NOT NULL THEN
      RAISE EXCEPTION 'Published HDC news history must be archived and retained';
    END IF;
    RETURN OLD;
  END IF;

  IF NEW.status = 'published' THEN
    NEW.ever_published := true;
    IF NEW.kind = 'recognition' AND NEW.recognition_consent_confirmed = true THEN
      NEW.recognition_consent_at := COALESCE(
        NEW.recognition_consent_at,
        OLD.recognition_consent_at,
        now()
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.hdc_public_news_lifecycle_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_public_news_lifecycle_guard() TO hdc_app;

DROP TRIGGER IF EXISTS hdc_public_news_lifecycle_guard
  ON public.hdc_public_news_posts;
CREATE TRIGGER hdc_public_news_lifecycle_guard
BEFORE INSERT OR UPDATE OR DELETE ON public.hdc_public_news_posts
FOR EACH ROW EXECUTE FUNCTION public.hdc_public_news_lifecycle_guard();

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0020', 'build26_news_consent_history', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
