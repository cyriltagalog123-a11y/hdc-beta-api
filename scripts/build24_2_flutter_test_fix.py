from pathlib import Path
import re

path = Path('test/unit/hdc_api_auth_gateway_test.dart')
text = path.read_text()

text = text.replace(
    "expect(request.url.path, '/api/auth/register');",
    "expect(request.url.path, '/api/auth/register-v2');",
    1,
)

location_assertion = "        expect(body['location'], 'Cebu City, Central Visayas, Philippines');\n"
if location_assertion not in text:
    anchor = "        expect(body['termsVersion'], hdcCurrentTermsVersion);\n"
    if anchor not in text:
        raise SystemExit('Registration body assertion anchor not found')
    text = text.replace(anchor, anchor + location_assertion, 1)

pattern = re.compile(
    r"^(?P<indent>[ \t]*)displayName: 'HDC Person',\n(?P=indent)recoveryAnswers: _recoveryAnswers,",
    re.MULTILINE,
)

def add_location(match: re.Match[str]) -> str:
    indent = match.group('indent')
    return (
        f"{indent}displayName: 'HDC Person',\n"
        f"{indent}location: 'Cebu City, Central Visayas, Philippines',\n"
        f"{indent}recoveryAnswers: _recoveryAnswers,"
    )

text, count = pattern.subn(add_location, text)
if count != 2:
    raise SystemExit(f'Expected two signUp calls to patch, found {count}')

path.write_text(text)
print('Build 24.2 Flutter registration tests patched successfully.')
