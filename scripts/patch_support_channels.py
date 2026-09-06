from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)

support_path = Path('lib/features/support/support_us_screen.dart')
support = support_path.read_text()
support = replace_once(
    support,
    "      (\n        'PayPal',\n        'Optional online contribution route',\n        'Account/link verification required',\n        Icons.public_rounded,\n      ),\n      (\n        'Ko-fi or similar',\n        'Useful for one-time or recurring support',\n        'SaiCore page/link required',\n        Icons.local_cafe_outlined,\n      ),\n",
    "",
    'remove PayPal and Ko-fi channels',
)
support = replace_once(
    support,
    "      (\n        'Bank / transfer route',\n        'Useful for larger PHP sponsorships',\n        'Published only after owner approval',\n        Icons.account_balance_outlined,\n      ),",
    "      (\n        'Bank / transfer route',\n        'Bank-transfer details may be added later after owner verification',\n        'Not available at the moment',\n        Icons.account_balance_outlined,\n      ),",
    'bank unavailable status',
)
support = replace_once(
    support,
    "            'The current policy is PHP-only and prefers channels with no required setup or monthly subscription cost. A provider may still charge transaction, processor, withdrawal, or conversion fees, so HDC will disclose those instead of advertising any route as universally fee-free.',",
    "            'The current policy is PHP-only and currently prioritizes verified local QR or wallet routes plus direct corporate arrangements. Available providers may still charge transaction or withdrawal fees, so HDC will disclose those instead of advertising any route as universally fee-free.',",
    'payment strategy copy',
)
support = replace_once(
    support,
    "                'Financial intake remains inactive until official SaiCore destination details are verified and published.',",
    "                'Payment destinations remain open for owner-supplied verified QR or account details. Bank transfer is not available at the moment.',",
    'payment destination status',
)
support_path.write_text(support)

test_path = Path('tests/support-contact-pages.test.ts')
test = test_path.read_text()
test = replace_once(
    test,
    "    expect(page).toContain('PayPal');\n    expect(page).toContain('Ko-fi or similar');\n    expect(page).toContain('Bank / transfer route');",
    "    expect(page).not.toContain('PayPal');\n    expect(page).not.toContain('Ko-fi or similar');\n    expect(page).toContain('Bank / transfer route');\n    expect(page).toContain('Not available at the moment');",
    'support channel expectations',
)
test = replace_once(
    test,
    "    expect(page).toContain('no required setup or monthly subscription cost');\n    expect(page).toContain('transaction, processor, withdrawal, or conversion fees');\n    expect(page).toContain('universally fee-free');\n    expect(page).toContain(\n      'Financial intake remains inactive until official SaiCore destination details are verified and published.',\n    );",
    "    expect(page).toContain('verified local QR or wallet routes');\n    expect(page).toContain('transaction or withdrawal fees');\n    expect(page).toContain('universally fee-free');\n    expect(page).toContain(\n      'Payment destinations remain open for owner-supplied verified QR or account details.',\n    );\n    expect(page).toContain('Bank transfer is not available at the moment.');",
    'fee and destination expectations',
)
test_path.write_text(test)
print('Support payment channels patched.')
