from pathlib import Path


def replace_exact(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text(encoding='utf-8')
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'Expected Build 27 patch marker not found in {path}: {old[:80]!r}')
    target.write_text(text.replace(old, new), encoding='utf-8')


replace_exact(
    'package-lock.json',
    '"version": "0.6.4-build.26"',
    '"version": "0.6.4-build.27"',
)
replace_exact(
    'lib/features/dashboard/dashboard_screen.dart',
    'HelpDesk Connect Beta v0.6.4 Build 26',
    'HelpDesk Connect Beta v0.6.4 Build 27',
)
replace_exact(
    'netlify/functions/api.mts',
    "build: '0.6.4-build26'",
    "build: '0.6.4-build27'",
)

readiness_old = """          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0020') AND
          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0021')
        ) AS latest_schema_ready,"""
readiness_new = """          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0020') AND
          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0021') AND
          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0022') AND
          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0023') AND
          EXISTS (SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0024') AND
          to_regclass('public.hdc_knowledge_articles') IS NOT NULL AND
          to_regclass('public.hdc_knowledge_article_versions') IS NOT NULL AND
          to_regclass('public.hdc_knowledge_feedback') IS NOT NULL
        ) AS latest_schema_ready,"""
replace_exact('netlify/functions/api.mts', readiness_old, readiness_new)

print('Build 27 release markers and readiness checks patched.')
