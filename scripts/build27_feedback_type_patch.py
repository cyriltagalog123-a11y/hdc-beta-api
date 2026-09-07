from pathlib import Path

path = Path('netlify/functions/knowledge.mts')
text = path.read_text(encoding='utf-8')

old = """  if (!publicArticleId || !Number.isInteger(version) || version < 1 || typeof body.helpful !== 'boolean') {
    return json({ error: 'invalid_knowledge_feedback' }, 400);
  }

  const articleRows = await sql`"""
new = """  if (!publicArticleId || !Number.isInteger(version) || version < 1 || typeof body.helpful !== 'boolean') {
    return json({ error: 'invalid_knowledge_feedback' }, 400);
  }
  const helpful: boolean = body.helpful;

  const articleRows = await sql`"""
if old not in text:
    raise SystemExit('feedback validation marker not found')
text = text.replace(old, new, 1)
text = text.replace('${authorization.userId}::uuid, ${body.helpful}, ${note}', '${authorization.userId}::uuid, ${helpful}, ${note}', 1)
text = text.replace('helpful: body.helpful,', 'helpful,', 1)
path.write_text(text, encoding='utf-8')
print('Build 27 knowledge feedback boolean narrowed.')
