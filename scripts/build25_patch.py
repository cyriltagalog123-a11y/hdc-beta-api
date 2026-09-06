from pathlib import Path

STAGE = 'Build 25B: redesign authentication and onboarding entry'


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:80]!r}')
    file_path.write_text(text.replace(old, new, 1))


def replace_all(path: str, old: str, new: str, expected: int) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected} matches, found {count}: {old[:80]!r}')
    file_path.write_text(text.replace(old, new))


login = 'lib/features/authentication/login_screen.dart'
replace_all(login, 'CONTROLLED BETA • BUILD 24', 'CONTROLLED BETA • BUILD 25', 2)
replace_once(
    login,
    "'Less searching.\\nMore solving.'",
    "'Your support network.\\nBuilt to stay connected.'",
)
replace_once(
    login,
    "'Less searching. More solving.'",
    "'Support, connected.'",
)
replace_once(
    login,
    "            Padding(\n              padding: const EdgeInsets.symmetric(horizontal: 28),\n              child: _AuthenticationModeSwitch(\n",
    "            const Padding(\n              padding: EdgeInsets.symmetric(horizontal: 28),\n              child: _AuthTrustStrip(),\n            ),\n            const SizedBox(height: 18),\n            Padding(\n              padding: const EdgeInsets.symmetric(horizontal: 28),\n              child: _AuthenticationModeSwitch(\n",
)
replace_once(
    login,
    "class _AuthenticationModeSwitch extends StatelessWidget {",
    """class _AuthTrustStrip extends StatelessWidget {
  const _AuthTrustStrip();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _AuthTrustItem(icon: Icons.verified_user_outlined, label: 'Backend-authoritative'),
        _AuthTrustItem(icon: Icons.account_tree_outlined, label: 'Role-aware'),
        _AuthTrustItem(icon: Icons.history_rounded, label: 'Tracked records'),
      ],
    );
  }
}

class _AuthTrustItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AuthTrustItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: HDCColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HDCColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: HDCColors.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthenticationModeSwitch extends StatelessWidget {""",
)

onboarding = 'lib/features/onboarding/platform_onboarding_screen.dart'
replace_once(onboarding, "eyebrow: 'ONE CONNECTED WORKSPACE',", "eyebrow: 'HDC NETWORK ONLINE',")
replace_once(onboarding, "title: 'Welcome to HDC',", "title: 'Enter your connected workspace',")
replace_once(
    onboarding,
    "'HelpDesk Connect brings technical support, trusted services, '\n          'products, and service history together in one platform.'",
    "'HelpDesk Connect keeps technical support, services, products, '\n          'and your authorized history connected around one account.'",
)
replace_once(onboarding, "label: const Text('Skip welcome'),", "label: const Text('Skip intro'),")

splash = 'lib/features/splash/splash_screen.dart'
replace_once(
    splash,
    "                  HDCBrandMark(size: 88, darkSurface: true),\n                  SizedBox(height: 28),\n",
    "                  HDCBrandMark(size: 88, darkSurface: true),\n                  SizedBox(height: 18),\n                  HDCSignalPill(\n                    label: 'BUILD 25 • HDC NETWORK',\n                    icon: Icons.hub_outlined,\n                    light: true,\n                  ),\n                  SizedBox(height: 24),\n",
)
replace_once(splash, "'Technical support, connected.'", "'One account. Every authorized support workflow, connected.'")

print(STAGE)
