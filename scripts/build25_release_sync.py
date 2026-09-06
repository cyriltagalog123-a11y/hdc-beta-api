from pathlib import Path


def replace_if_present(path: str, old: str, new: str) -> int:
    file_path = Path(path)
    text = file_path.read_text()
    count = text.count(old)
    if count:
        file_path.write_text(text.replace(old, new))
    return count

changes = 0
changes += replace_if_present('package-lock.json', '0.6.4-build.24', '0.6.4-build.25')
changes += replace_if_present('netlify/functions/api.mts', '0.6.4-build24', '0.6.4-build25')
changes += replace_if_present('web/index.html', 'Build 24', 'Build 25')
changes += replace_if_present(
    '.github/workflows/ci.yml',
    'hdc-web-build24',
    'hdc-web-build25',
)
changes += replace_if_present(
    '.github/workflows/ci.yml',
    'Synchronize verified Build 24 web bundle',
    'Synchronize verified Build 25 web bundle',
)
changes += replace_if_present(
    'lib/features/dashboard/dashboard_screen.dart',
    'HelpDesk Connect Beta v0.6.4 Build 24',
    'HelpDesk Connect Beta v0.6.4 Build 25',
)
changes += replace_if_present(
    'lib/core/config/app_config.dart',
    '0.6.4 Beta (Build 24)',
    '0.6.4 Beta (Build 25)',
)

print(f'Synchronized {changes} remaining Build 25 release marker(s).')
