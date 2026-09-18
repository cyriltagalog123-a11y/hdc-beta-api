function escapeHtml(value = '') {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

export function renderAdmin({ pages, audit, warning, error }) {
  const pageRows = pages.length
    ? pages.map((page) => `
      <tr>
        <td>${escapeHtml(page.pageName)}</td>
        <td><code>${escapeHtml(page.pageId)}</code></td>
        <td>${escapeHtml((page.tasks || []).join(', ') || '—')}</td>
        <td>${escapeHtml(new Date(page.connectedAt).toLocaleString())}</td>
      </tr>`).join('')
    : '<tr><td colspan="4">No Facebook Page connected yet.</td></tr>';

  const pageOptions = pages.map((page) => `<option value="${escapeHtml(page.pageId)}">${escapeHtml(page.pageName)}</option>`).join('');

  const auditRows = audit.length
    ? audit.map((entry) => `
      <tr>
        <td>${escapeHtml(new Date(entry.createdAt).toLocaleString())}</td>
        <td>${escapeHtml(entry.action)}</td>
        <td>${escapeHtml(entry.pageId || '—')}</td>
        <td>${entry.success ? '✅' : '❌'}</td>
      </tr>`).join('')
    : '<tr><td colspan="4">No actions recorded yet.</td></tr>';

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>HDC Social Bridge</title>
<style>
:root { color-scheme: dark; --bg:#07111f; --panel:#0d1a2d; --line:#1d3555; --blue:#48a7ff; --text:#e9f3ff; --muted:#9fb6ce; }
*{box-sizing:border-box} body{margin:0;font:15px/1.5 system-ui,Segoe UI,Arial;background:linear-gradient(145deg,#050b14,#081a2e);color:var(--text)}
main{max-width:1050px;margin:0 auto;padding:34px 20px 60px}.brand{display:flex;align-items:center;gap:14px;margin-bottom:24px}.mark{width:46px;height:46px;border:2px solid var(--blue);display:grid;place-items:center;clip-path:polygon(25% 7%,75% 7%,100% 50%,75% 93%,25% 93%,0 50%);color:var(--blue);font-weight:800;font-size:20px}.sub{color:var(--muted)}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:18px}.card{background:rgba(13,26,45,.92);border:1px solid var(--line);border-radius:14px;padding:20px;box-shadow:0 16px 50px rgba(0,0,0,.18)}.wide{grid-column:1/-1}h1,h2{margin-top:0}h1{font-size:24px}h2{font-size:17px;color:#d8ebff}
button,.btn{background:var(--blue);color:#00101f;border:0;border-radius:9px;padding:10px 14px;font-weight:700;text-decoration:none;display:inline-block;cursor:pointer}textarea,select{width:100%;background:#07111f;color:var(--text);border:1px solid var(--line);border-radius:9px;padding:10px;margin:8px 0 12px}textarea{min-height:145px;resize:vertical}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:9px 8px;border-bottom:1px solid #18304c;vertical-align:top}th{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.05em}code{color:#9bd0ff}.notice{border-left:3px solid var(--blue);padding:10px 12px;background:#071827;margin-bottom:18px}.error{border-left-color:#ff7f87}.muted{color:var(--muted);font-size:13px}@media(max-width:760px){.grid{grid-template-columns:1fr}.wide{grid-column:auto}}
</style>
</head>
<body><main>
<div class="brand"><div class="mark">H</div><div><h1>HDC Social Bridge</h1><div class="sub">Private Facebook Page publishing bridge · Build 0.1</div></div></div>
${warning ? `<div class="notice">${escapeHtml(warning)}</div>` : ''}
${error ? `<div class="notice error">${escapeHtml(error)}</div>` : ''}
<div class="grid">
<section class="card"><h2>Facebook connection</h2><p>Connect the Facebook account that has full Page access to HelpDesk Connect.</p><a class="btn" href="/auth/facebook">Connect / refresh Facebook</a><p class="muted">Requested scopes: pages_show_list, pages_read_engagement, pages_manage_posts.</p></section>
<section class="card"><h2>Controlled test publish</h2><form method="post" action="/admin/publish"><label>Page</label><select name="pageId" required>${pageOptions || '<option value="">Connect a Page first</option>'}</select><label>Post text</label><textarea name="message" required></textarea><button type="submit">Publish now</button></form><p class="muted">This is the owner-only test surface. MCP publishing separately requires confirm=true.</p></section>
<section class="card wide"><h2>Connected Pages</h2><table><thead><tr><th>Name</th><th>Page ID</th><th>Tasks</th><th>Connected</th></tr></thead><tbody>${pageRows}</tbody></table></section>
<section class="card wide"><h2>Recent audit log</h2><table><thead><tr><th>Time</th><th>Action</th><th>Page</th><th>Status</th></tr></thead><tbody>${auditRows}</tbody></table></section>
</div></main></body></html>`;
}

export function renderCallbackSuccess(pages) {
  return `<!doctype html><html><body style="font-family:system-ui;background:#07111f;color:white;padding:40px"><h1>Facebook connected</h1><p>Stored ${pages.length} manageable Page${pages.length === 1 ? '' : 's'} securely.</p><p><a style="color:#48a7ff" href="/admin">Return to HDC Social Bridge</a></p></body></html>`;
}
