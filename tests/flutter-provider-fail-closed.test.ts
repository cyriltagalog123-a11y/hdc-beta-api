import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

function source(path: string): string {
  return readFileSync(fileURLToPath(new URL(path, import.meta.url)), 'utf8');
}

describe('Flutter backend provider selection', () => {
  it('allows local storage only for the explicit local provider', () => {
    const config = source('../lib/core/backend/backend_config.dart');
    const localCase = config.match(
      /case 'local':\s*return HDCBackendProvider\.local;/,
    );
    const unknownCase = config.match(
      /default:\s*throw StateError\([\s\S]*?Unsupported HDC_BACKEND_PROVIDER/,
    );

    expect(localCase).not.toBeNull();
    expect(unknownCase).not.toBeNull();
    expect(config).not.toMatch(/default:\s*return HDCBackendProvider\.local/);
  });

  it('keeps unknown or invalid configuration on remote fail-closed stores', () => {
    const main = source('../lib/main.dart');

    expect(main).toMatch(
      /if \(backendProvider != HDCBackendProvider\.local\)/,
    );
    expect(main).toContain("Uri.parse('https://configuration.invalid')");
    expect(main.indexOf('SharedPreferencesProposalRepository()')).toBeGreaterThan(
      main.indexOf('} else {'),
    );
  });
});
