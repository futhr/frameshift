import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';
import { attempt, centerCrop, dwellDecision, newSession, profileDecision, queue } from '../dist/lab.mjs';

for (const kind of ['photo', 'pixel']) {
  test(`${kind} admits its illustrative RGB24 profile`, () => {
    assert.equal(profileDecision(kind).admitted, true);
    let state = queue(newSession(kind));
    assert.equal(state.current, 'Previous still');
    for (const event of ['loss', 'restart', 'version', 'digest', 'unknown']) {
      state = attempt(state, event);
      assert.equal(state.current, 'Previous still');
      assert.equal(state.desired?.revision, 1);
    }
    state = attempt(state, 'confirm');
    assert.equal(state.current, 'Still 1');
    assert.equal(state.desired, null);
  });
}

test('Paper capability refuses RGB24 while conceptual pull remains pending', () => {
  assert.deepEqual(profileDecision('paper'), {
    admitted: false, reason: 'UnsupportedProfile',
  });
  let state = queue(newSession('paper'));
  for (const event of ['loss', 'restart', 'version', 'digest', 'unknown']) {
    state = attempt(state, event);
    assert.equal(state.current, 'Previous still');
    assert.equal(state.desired?.revision, 1);
  }
  assert.equal(attempt(state, 'confirm').current, 'Still 1');
});

test('dwell follows the shared minimum and refuses unsafe input', () => {
  assert.deepEqual(dwellDecision('paper', 60), { admitted: true, seconds: 180 });
  assert.deepEqual(dwellDecision('paper', 21_600), { admitted: true, seconds: 21_600 });
  assert.deepEqual(dwellDecision('photo', 60), { admitted: true, seconds: 60 });
  assert.equal(dwellDecision('paper', 0).admitted, false);
  assert.equal(dwellDecision('paper', 1.5).admitted, false);
  assert.equal(dwellDecision('paper', Number.MAX_SAFE_INTEGER + 1).admitted, false);
});

test('illustrative crop preserves the selected frame aspect ratio', () => {
  assert.deepEqual(centerCrop(2000, 1000, 1000, 1000), {
    x: 500, y: 0, width: 1000, height: 1000,
  });
  assert.deepEqual(centerCrop(1000, 2000, 1000, 1000), {
    x: 0, y: 500, width: 1000, height: 1000,
  });
  assert.throws(() => centerCrop(0, 1000, 1000, 1000), RangeError);
});

test('lab revision count is bounded', () => {
  const state = { ...newSession('photo'), revision: 9_999 };
  assert.equal(queue(state).revision, 9_999);
  assert.match(queue(state).status, /limit reached/);
});

test('built guide contains no remote or executable service dependency', () => {
  const output = resolve(import.meta.dirname, '../dist');
  const html = readFileSync(resolve(output, 'index.html'), 'utf8');
  const headers = readFileSync(resolve(output, '_headers'), 'utf8');
  assert.match(html, /Installation artifacts are not yet available/);
  assert.doesNotMatch(html, /<script(?![^>]*type="module")/i);
  assert.doesNotMatch(html, /https?:\/\//i);
  assert.match(headers, /connect-src 'none'/);
  assert.match(headers, /frame-ancestors 'none'/);
  let count = 0;
  const walk = directory => {
    for (const name of readdirSync(directory)) {
      const path = resolve(directory, name);
      const stats = statSync(path);
      if (stats.isDirectory()) walk(path);
      else {
        assert.ok(stats.size <= 25 * 1024 * 1024, path);
        count += 1;
      }
    }
  };
  walk(output);
  assert.ok(count > 10);
});
