from pathlib import Path

STAGE = 'Build 25G: synchronize Build 25 release identity'


def replace_exact(path: str, old: str, new: str, expected: int = 1) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected} matches, found {count}: {old!r}')
    file_path.write_text(text.replace(old, new))


replace_exact('package.json', '"version": "0.6.4-build.24"', '"version": "0.6.4-build.25"')
replace_exact(
    'package-lock.json',
    '"version": "0.6.4-build.24"',
    '"version": "0.6.4-build.25"',
    expected=2,
)
replace_exact('pubspec.yaml', 'version: 0.6.4+24', 'version: 0.6.4+25')
replace_exact(
    'lib/core/config/app_config.dart',
    '0.6.4 Beta (Build 24)',
    '0.6.4 Beta (Build 25)',
)
replace_exact(
    'lib/features/dashboard/dashboard_screen.dart',
    'HelpDesk Connect Beta v0.6.4 Build 24',
    'HelpDesk Connect Beta v0.6.4 Build 25',
)
replace_exact(
    'netlify/functions/api.mts',
    '0.6.4-build24',
    '0.6.4-build25',
)
replace_exact('web/index.html', 'Build 24', 'Build 25', expected=2)
replace_exact(
    '.github/workflows/ci.yml',
    'name: hdc-web-build24',
    'name: hdc-web-build25',
)
replace_exact(
    '.github/workflows/ci.yml',
    'Synchronize verified Build 24 web bundle',
    'Synchronize verified Build 25 web bundle',
)

print(STAGE)
