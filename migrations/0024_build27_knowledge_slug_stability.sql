-- Build 27: preserve published Knowledge Base URLs once an article becomes public.
-- Draft-only slugs may change, but public guide slugs become stable after first publication.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_knowledge_articles') IS NULL
     OR to_regclass('public.hdc_knowledge_article_versions') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0023'
     ) THEN
    RAISE EXCEPTION 'HDC migration 0023 must be applied first';
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.hdc_lock_published_knowledge_slug()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  IF OLD.ever_published = true AND NEW.slug IS DISTINCT FROM OLD.slug THEN
    RAISE EXCEPTION 'Published HDC knowledge slugs are permanent. Create a new article instead.';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.hdc_lock_published_knowledge_slug() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_lock_published_knowledge_slug() TO hdc_app;

DROP TRIGGER IF EXISTS hdc_lock_published_knowledge_slug
  ON public.hdc_knowledge_articles;

CREATE TRIGGER hdc_lock_published_knowledge_slug
BEFORE UPDATE OF slug
ON public.hdc_knowledge_articles
FOR EACH ROW
EXECUTE FUNCTION public.hdc_lock_published_knowledge_slug();

CREATE OR REPLACE FUNCTION public.hdc_retain_published_knowledge_history()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  IF OLD.ever_published = true OR OLD.published_version IS NOT NULL THEN
    RAISE EXCEPTION 'Published HDC knowledge history must be archived and retained.';
  END IF;
  RETURN OLD;
END;
$$;

REVOKE ALL ON FUNCTION public.hdc_retain_published_knowledge_history() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_retain_published_knowledge_history() TO hdc_app;

DROP TRIGGER IF EXISTS hdc_retain_published_knowledge_history
  ON public.hdc_knowledge_articles;

CREATE TRIGGER hdc_retain_published_knowledge_history
BEFORE DELETE
ON public.hdc_knowledge_articles
FOR EACH ROW
EXECUTE FUNCTION public.hdc_retain_published_knowledge_history();

CREATE OR REPLACE FUNCTION public.hdc_lock_knowledge_article_version()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'HDC knowledge article versions are immutable.';
  END IF;
  IF OLD.published_at IS NOT NULL OR EXISTS (
    SELECT 1
    FROM public.hdc_knowledge_articles article
    WHERE article.id = OLD.article_id
      AND article.ever_published = true
  ) THEN
    RAISE EXCEPTION 'Published HDC knowledge versions must be retained.';
  END IF;
  RETURN OLD;
END;
$$;

REVOKE ALL ON FUNCTION public.hdc_lock_knowledge_article_version() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hdc_lock_knowledge_article_version() TO hdc_app;

DROP TRIGGER IF EXISTS hdc_lock_knowledge_article_version
  ON public.hdc_knowledge_article_versions;

CREATE TRIGGER hdc_lock_knowledge_article_version
BEFORE UPDATE OR DELETE
ON public.hdc_knowledge_article_versions
FOR EACH ROW
EXECUTE FUNCTION public.hdc_lock_knowledge_article_version();

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0024', 'build27_knowledge_slug_stability', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
