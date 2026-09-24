import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';
import { installVerifiedRelease } from '../release-markup.mjs';

const template = readFileSync(resolve(import.meta.dirname, '../src/index.html'), 'utf8');

test('verified platform links replace the unavailable note once', () => {
  const html = installVerifiedRelease(template, {
    version: '1.2.3',
    artifacts: [{ platform: 'macos', architecture: 'universal', format: 'dmg',
      url: 'https://example.com/releases/v1.2.3/Frameshift-1.2.3.dmg' }],
  });
  assert.match(html, /Verified host release 1\.2\.3/);
  assert.match(html, /macOS universal installer/);
  assert.match(html, /href="https:\/\/example\.com\/releases\/v1\.2\.3\/Frameshift-1\.2\.3\.dmg"/);
  assert.doesNotMatch(html, /Installation artifacts are not yet available/);
  assert.throws(() => installVerifiedRelease(html, { version: '1.2.3', artifacts: [] }),
    /placeholder/);
});
