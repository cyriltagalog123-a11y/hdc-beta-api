from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old!r}')
    p.write_text(text.replace(old, new, 1))

# Preserve the stable Build 24A widget selector while keeping the new dropdown UI.
replace_once(
    'lib/features/service_requests/create_service_request_screen.dart',
    "          HdcLocationPicker(\n            value: _locationController.text.isEmpty ? null : _locationController.text,",
    "          HdcLocationPicker(\n            key: const Key('hdc-request-location'),\n            value: _locationController.text.isEmpty ? null : _locationController.text,",
)

# Integration fixtures must use the same canonical location accepted in production.
replace_once(
    'tests/postgres-workflows.integration.test.ts',
    "      location: 'Cebu City',",
    "      location: 'Cebu City, Central Visayas, Philippines',",
)

# Remove one-time diagnostics from the product branch.
for path in [
    Path('build24-2-test-result.json'),
    Path('.github/workflows/build24-2-test-diagnostic.yml'),
]:
    if path.exists():
        path.unlink()

print('Build 24.2 CI compatibility fixes applied.')
