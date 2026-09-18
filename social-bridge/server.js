import { createApp } from './src/app.js';

const port = Number(process.env.PORT || 8787);
const app = await createApp();

app.listen(port, () => {
  console.log(`HDC Social Bridge listening on http://localhost:${port}`);
});
