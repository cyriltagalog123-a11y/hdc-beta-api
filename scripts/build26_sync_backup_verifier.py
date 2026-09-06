from pathlib import Path

path = Path('scripts/postgres/verify-backup.mjs')
text = path.read_text(encoding='utf-8')

old_query = """        (SELECT count(*)::int FROM public.hdc_legal_documents
          WHERE document_version = 'beta-2026-08-29'
            AND status = 'published') AS legal_documents,"""
new_query = """        (SELECT count(*)::int FROM public.hdc_legal_documents
          WHERE document_version = 'beta-2026-09-06'
            AND status = 'published') AS legal_documents,
        (SELECT count(*)::int FROM public.hdc_legal_documents
          WHERE document_version = 'beta-2026-08-29'
            AND status = 'superseded') AS superseded_legal_documents,"""

if old_query in text:
    text = text.replace(old_query, new_query, 1)
elif 'AS superseded_legal_documents' not in text:
    raise SystemExit('legal readiness query marker not found')

old_check = """      Number(row.legal_documents) !== 2 ||
      Number(row.invalid_constraints) !== 0 ||"""
new_check = """      Number(row.legal_documents) !== 2 ||
      Number(row.superseded_legal_documents) !== 2 ||
      Number(row.invalid_constraints) !== 0 ||"""

if old_check in text:
    text = text.replace(old_check, new_check, 1)
elif 'Number(row.superseded_legal_documents) !== 2' not in text:
    raise SystemExit('legal readiness condition marker not found')

path.write_text(text, encoding='utf-8')
print('Build 26 backup verifier legal readiness synchronized.')
