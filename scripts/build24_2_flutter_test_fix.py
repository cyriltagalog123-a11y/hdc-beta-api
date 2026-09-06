from pathlib import Path

path = Path('test/unit/hdc_api_auth_gateway_test.dart')
text = path.read_text()

old_path = "expect(request.url.path, '/api/auth/register');"
if text.count(old_path) != 1:
    raise SystemExit(f'Expected one old registration path, found {text.count(old_path)}')
text = text.replace(old_path, "expect(request.url.path, '/api/auth/register-v2');", 1)

anchor = "        expect(body['termsVersion'], hdcCurrentTermsVersion);\n"
if text.count(anchor) != 1:
    raise SystemExit('Registration body assertion anchor not found exactly once')
text = text.replace(
    anchor,
    anchor + "        expect(body['location'], 'Cebu City, Central Visayas, Philippines');\n",
    1,
)

call = "        displayName: 'HDC Person',\n        recoveryAnswers: _recoveryAnswers,"
count = text.count(call)
if count != 2:
    raise SystemExit(f'Expected two signUp calls to patch, found {count}')
text = text.replace(
    call,
    "        displayName: 'HDC Person',\n        location: 'Cebu City, Central Visayas, Philippines',\n        recoveryAnswers: _recoveryAnswers,",
)

path.write_text(text)
print('Build 24.2 auth gateway Flutter tests updated for controlled registration location.')
