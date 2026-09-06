from pathlib import Path

for name in ['netlify/functions/register-v2.mts', 'netlify/functions/platform-role-admin.mts']:
    path = Path(name)
    text = path.read_text()
    text = text.replace("import type { Config } from '@netlify/functions';\n", '', 1)
    text = text.replace('export const config: Config = {', 'export const config = {', 1)
    if "@netlify/functions" in text:
        raise SystemExit(f'{name}: hosting SDK reference remains')
    path.write_text(text)

print('Build 24.2 standalone function portability fixed.')
