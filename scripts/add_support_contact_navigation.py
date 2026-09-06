from pathlib import Path

path = Path('lib/features/dashboard/dashboard_screen.dart')
text = path.read_text()


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Expected one match, found {count}: {old[:100]!r}')
    text = text.replace(old, new, 1)


replace_once(
    "import '../search/search_screen.dart';\n",
    "import '../search/search_screen.dart';\nimport '../support/contact_owner_screen.dart';\nimport '../support/support_us_screen.dart';\n",
)

replace_once(
    "  Future<void> _openPassport(BuildContext context) async {\n    if (!await requireRegisteredUser(\n      context,\n      action: 'open your HDC Passport',\n    )) {\n      return;\n    }\n    if (!context.mounted) return;\n    _showComingSoon(context, 'HDC Passport');\n  }\n",
    "  Future<void> _openPassport(BuildContext context) async {\n    if (!await requireRegisteredUser(\n      context,\n      action: 'open your HDC Passport',\n    )) {\n      return;\n    }\n    if (!context.mounted) return;\n    _showComingSoon(context, 'HDC Passport');\n  }\n\n  void _openSupportUs(BuildContext context) {\n    Navigator.of(context).push(\n      HDCPageRoute<void>(page: const SupportUsScreen()),\n    );\n  }\n\n  void _openContactOwner(BuildContext context) {\n    Navigator.of(context).push(\n      HDCPageRoute<void>(page: const ContactOwnerScreen()),\n    );\n  }\n",
)

replace_once(
    "      HDCNavigationItem(\n        label: 'HDC Passport',\n        icon: Icons.fingerprint_rounded,\n        onTap: () => _openPassport(context),\n      ),\n      if (hasPrivateWorkspace)\n",
    "      HDCNavigationItem(\n        label: 'HDC Passport',\n        icon: Icons.fingerprint_rounded,\n        onTap: () => _openPassport(context),\n      ),\n      HDCNavigationItem(\n        label: 'Support HDC',\n        icon: Icons.volunteer_activism_outlined,\n        onTap: () => _openSupportUs(context),\n      ),\n      HDCNavigationItem(\n        label: 'Contact Owner',\n        icon: Icons.alternate_email_rounded,\n        onTap: () => _openContactOwner(context),\n      ),\n      if (hasPrivateWorkspace)\n",
)

path.write_text(text)
print('Support HDC and Contact Owner navigation wired.')
