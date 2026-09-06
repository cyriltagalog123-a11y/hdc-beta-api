from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def read(path): return (ROOT / path).read_text(encoding='utf-8')
def write(path, text): (ROOT / path).write_text(text, encoding='utf-8')
def replace(path, old, new, count=-1):
    text = read(path)
    if old not in text:
        raise RuntimeError(f'missing marker in {path}: {old[:100]!r}')
    write(path, text.replace(old, new, count))

# Dashboard: Passport is intentionally hidden until implemented; remove all remaining callbacks and dead helper.
p='lib/features/dashboard/dashboard_screen.dart'
t=read(p)
t,n=re.subn(r"\n  void _showComingSoon\(BuildContext context, String feature\) \{.*?\n  \}\n", '\n', t, count=1, flags=re.S)
if n != 1: raise RuntimeError('could not remove _showComingSoon')
t=t.replace("                                onPassport: () => _openPassport(context),\n", '')
t=t.replace("                          onPassport: () => _openPassport(context),\n", '')
if '_openPassport' in t: raise RuntimeError('remaining Passport callback in dashboard')
write(p,t)

# PostgreSQL integration must use the canonical controlled-location registration contract.
p='tests/postgres-workflows.integration.test.ts'
t=read(p)
needle="      displayName: `HDC ${label}`,\n      recoveryAnswers: ["
if needle not in t: raise RuntimeError('registration fixture marker missing')
t=t.replace(needle, "      displayName: `HDC ${label}`,\n      location: 'Cebu City, Central Visayas, Philippines',\n      recoveryAnswers: [", 1)
write(p,t)

# Historical UI tests should assert the current release identity without rewriting their historical scope.
replace('tests/build23-ui-foundation.test.ts', "expect(index).toContain('Build 25');", "expect(index).toContain('Build 26');")
replace('tests/build23-ui-foundation.test.ts', "expect(startup).toContain('Build 25 could not finish loading.');", "expect(startup).toContain('Build 26 could not finish loading.');")

p='tests/build24a-request-discovery.test.ts'
t=read(p)
t=t.replace("keeps the public release identity synchronized to Build 25", "keeps the public release identity synchronized to the current build")
t=t.replace("expect(login).toContain('CONTROLLED BETA • BUILD 25');", "expect(login).toContain('CONTROLLED BETA • BUILD 26');")
t=t.replace("const release = read('README_BUILD_0_6_4_BUILD24A.txt');", "const release = read('docs/archive/builds/README_BUILD_0_6_4_BUILD24A.txt');")
write(p,t)

p='tests/build25-interface-redesign.test.ts'
t=read(p)
t=t.replace("synchronizes the public release identity to Build 25", "keeps the Build 25 redesign synchronized to the current release")
t=t.replace("expect(appConfig).toContain('0.6.4 Beta (Build 25)');", "expect(appConfig).toContain('0.6.4 Beta (Build 26)');")
t=t.replace("expect(dashboard).toContain('HelpDesk Connect Beta v0.6.4 Build 25');", "expect(dashboard).toContain('HelpDesk Connect Beta v0.6.4 Build 26');")
t=t.replace("expect(startup).toContain('Build 25');", "expect(startup).toContain('Build 26');")
t=t.replace("    expect(ci).toContain('name: hdc-web-build25');\n    expect(ci).toContain('Synchronize verified Build 25 web bundle');", "    expect(ci).toContain('steps.release-artifact.outputs.name');\n    expect(ci).not.toContain('git push origin');")
write(p,t)

p='tests/news-support-knowledge.test.ts'
t=read(p)
t=t.replace("describe('HDC News, recognition, and Build 26 preparation'", "describe('HDC News, recognition, and Build 27 preparation'")
t=t.replace("    const api = read('netlify/functions/news-admin.mts');\n    expect(api).toContain(\"path: '/api/internal/news'\");", "    const api = read('netlify/functions/news-admin.mts');\n    const internalAuth = read('netlify/functions/_lib/internal-auth.mts');\n    expect(api).toContain(\"path: '/api/internal/news'\");")
t=t.replace("    expect(api).toContain('verifySessionToken');", "    expect(api).toContain('authorizeInternalRequest');\n    expect(internalAuth).toContain('verifySessionToken');\n    expect(internalAuth).toContain('hdc_internal_role_assignments');")
t=t.replace("keeps Knowledge Base implementation explicitly deferred to Build 26", "keeps Knowledge Base implementation explicitly deferred to Build 27")
t=t.replace("expect(kb).toContain('BUILD 26 READY');", "expect(kb).toContain('BUILD 27 READY');")
t=t.replace("expect(kb).toContain('Search becomes active in Build 26');", "expect(kb).toContain('Search becomes active in Build 27');")
write(p,t)

p='tests/web-startup-recovery.test.ts'
t=read(p).replace('renders a visible Build 25 loading state before Flutter starts', 'renders a visible Build 26 loading state before Flutter starts')
t=t.replace("expect(index).toContain('Build 25');", "expect(index).toContain('Build 26');")
write(p,t)

# News create/update responses must return the richer consent/history fields immediately.
p='netlify/functions/news-admin.mts'
t=read(p)
old="""        recognition_subject, recognition_consent_confirmed,
        published_at, created_at, updated_at"""
new="""        recognition_subject, recognition_consent_confirmed, recognition_consent_at,
        recognition_consent_method, recognition_consent_scope, recognition_consent_reference,
        ever_published, published_at, created_at, updated_at"""
if t.count(old) != 2: raise RuntimeError(f'expected 2 news RETURNING projections, got {t.count(old)}')
t=t.replace(old,new)
write(p,t)

# Strengthen regression coverage for the immediate News response contract.
p='tests/build26-hardening.test.ts'
t=read(p)
needle="    expect(admin).toContain('recognitionConsentScope');\n    expect(admin).toContain('ever_published = false');"
if needle not in t: raise RuntimeError('Build26 news regression marker missing')
t=t.replace(needle, needle + "\n    expect(admin).toContain('recognition_consent_at');\n    expect(admin).toContain('recognition_consent_reference');")
write(p,t)

print('Build 26 final fixes applied.')
