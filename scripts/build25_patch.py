from pathlib import Path

STAGE = 'Build 25F: clean obsolete interface helpers'


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:100]!r}')
    file_path.write_text(text.replace(old, new, 1))


def delete_between(path: str, start: str, end: str) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    start_index = text.find(start)
    if start_index < 0:
        raise SystemExit(f'{path}: missing start marker {start!r}')
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise SystemExit(f'{path}: missing end marker {end!r}')
    file_path.write_text(text[:start_index] + text[end_index:])


replace_once(
    'lib/features/internal/internal_dashboard_screen.dart',
    "import '../../core/ui/hdc_flow.dart';\n",
    '',
)

delete_between(
    'lib/features/profiles/profile_center_screen.dart',
    'class _OneAccountBanner extends StatelessWidget {',
    'class _MemberProfileCard extends StatelessWidget {',
)

delete_between(
    'lib/features/marketplace/marketplace_catalog_screen.dart',
    'class _CatalogNotice extends StatelessWidget {',
    'class _ProductCard extends StatelessWidget {',
)

print(STAGE)
