from pathlib import Path

path = Path('tests/build26-community.integration.test.ts')
text = path.read_text()

def replace_once(old, new, label):
    global text
    if old not in text:
        raise SystemExit(f'missing target: {label}')
    text = text.replace(old, new, 1)

replace_once(
    "let admin: TestAccount;\nlet sequence = 0;",
    "let admin: TestAccount;\nlet owner: TestAccount;\nlet sequence = 0;",
    'owner variable',
)
replace_once(
    "      const rawAdmin = await register('Suggestion Admin');",
    "      const rawAdmin = await register('Suggestion Admin');\n      const rawOwner = await register('Suggestion Owner');",
    'owner registration',
)
replace_once(
    "        ) VALUES (\n          ${rawAdmin.id}::uuid, 'admin', true, 'Build 26 community integration test'\n        )\n        ON CONFLICT(user_id, role) DO UPDATE SET is_active = true",
    "        ) VALUES\n          (${rawAdmin.id}::uuid, 'admin', true, 'Build 26 admin denial regression'),\n          (${rawOwner.id}::uuid, 'owner', true, 'Build 26 owner suggestion regression')\n        ON CONFLICT(user_id, role) DO UPDATE SET is_active = true",
    'owner role fixture',
)
replace_once(
    "      admin = await login(rawAdmin);",
    "      admin = await login(rawAdmin);\n      owner = await login(rawOwner);",
    'owner login',
)
replace_once(
    "    it('tracks suggestions, restricts management, and awards Helpful Contributor only after implementation', async () => {",
    "    it('tracks suggestions, restricts full management to Owner, and awards Helpful Contributor only after implementation', async () => {",
    'test name',
)
replace_once(
    "      const queue = await adminApi('/api/internal/community', {}, admin.token);\n      expectStatus(queue, 200);",
    "      const deniedAdmin = await adminApi('/api/internal/community', {}, admin.token);\n      expectStatus(deniedAdmin, 403);\n      expect(deniedAdmin.body.error).toBe('suggestion_management_forbidden');\n\n      const queue = await adminApi('/api/internal/community', {}, owner.token);\n      expectStatus(queue, 200);",
    'admin denial owner queue',
)
replace_once(
    "      }, admin.token);\n      expectStatus(implemented, 200);",
    "      }, owner.token);\n      expectStatus(implemented, 200);",
    'owner implementation',
)

path.write_text(text)
print('Owner-only suggestion integration regression updated.')
