-- Build 27: preserve published Knowledge Base URLs once an article becomes public.
-- Draft-only slugs may change, but public guide slugs become stable after first publication.

CREATE OR REPLACE FUNCTION public.hdc_lock_published_knowledge_slug()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.ever_published = true AND NEW.slug IS DISTINCT FROM OLD.slug THEN
    RAISE EXCEPTION 'Published HDC knowledge slugs are permanent. Create a new article instead.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS hdc_lock_published_knowledge_slug
  ON public.hdc_knowledge_articles;

CREATE TRIGGER hdc_lock_published_knowledge_slug
BEFORE UPDATE OF slug
ON public.hdc_knowledge_articles
FOR EACH ROW
EXECUTE FUNCTION public.hdc_lock_published_knowledge_slug();
