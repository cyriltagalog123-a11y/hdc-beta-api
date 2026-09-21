import { createApp } from './src/app.js';
import { runOAuthMcpSmokeTest } from './src/smoke.js';

const port = Number(process.env.PORT || 8787);
const app = await createApp();

if (String(process.env.SMOKE_TEST_ENABLED || '').toLowerCase() === 'true') {
  app.get('/internal/smoke/oauth-mcp', async (_req, res) => {
    try {
      const result = await runOAuthMcpSmokeTest();
      res.json(result);
    } catch (error) {
      console.error('OAuth MCP smoke test failed', error);
      res.status(500).json({
        ok: false,
        error: error.message,
        details: error.details || null
      });
    }
  });
}

app.listen(port, () => {
  console.log(`HDC Social Bridge listening on http://localhost:${port}`);
});
