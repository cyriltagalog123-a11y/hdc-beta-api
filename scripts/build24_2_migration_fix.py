from pathlib import Path
import hashlib, json


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old!r}')
    p.write_text(text.replace(old, new, 1))

pre17 = """BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0016'
     ) THEN
    RAISE EXCEPTION 'HDC migrations 0000 through 0016 must be applied first';
  END IF;
END
$$;
"""
replace_once('migrations/0017_controlled_locations.sql', 'BEGIN;\n', pre17)
replace_once(
    'migrations/0017_controlled_locations.sql',
    '\nCOMMIT;\n',
    """

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0017', 'controlled_locations', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
""",
)

pre18 = """BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0017'
     ) THEN
    RAISE EXCEPTION 'HDC migration 0017 must be applied first';
  END IF;
END
$$;
"""
replace_once('migrations/0018_controlled_role_application_locations.sql', 'BEGIN;\n', pre18)
replace_once(
    'migrations/0018_controlled_role_application_locations.sql',
    '\nCOMMIT;\n',
    """

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0018', 'controlled_role_application_locations', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
""",
)

manifest_path = Path('migrations/checksums.json')
manifest = json.loads(manifest_path.read_text())
for name in ['0017_controlled_locations.sql', '0018_controlled_role_application_locations.sql']:
    manifest['files'][name] = hashlib.sha256(Path('migrations', name).read_bytes()).hexdigest()
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')

print('Build 24.2 migration registration and checksums updated.')
