import { strict as assert } from 'node:assert';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { profileIdentity } from '../js/profile.mjs';

const fixture = await readFile(new URL('./fixtures/profile-v1.json', import.meta.url), 'utf8');
const identity = 'sha256:bca6740b4b3726d310ef42735c1d45f40682f767816ff299f02ed6a4143d2278';

test('standard Web Crypto identity matches the BEAM golden fixture', async () => {
  assert.deepEqual(await profileIdentity(fixture), { ok: true, identity });
  const changed = await profileIdentity(fixture.replace('"part_revision":"R1"', '"part_revision":"R2"'));
  assert.equal(changed.ok, true);
  assert.notEqual(changed.identity, identity);
});

test('untrusted boundary types and ambiguous wire numbers are refused', async () => {
  for (const input of [null, undefined, {}, 1, new Uint8Array([255]), '{}', '"\\uD800"']) {
    assert.deepEqual(await profileIdentity(input), { ok: false, error: 'invalid_document' });
  }
  assert.deepEqual(await profileIdentity(` ${fixture}`), { ok: false, error: 'noncanonical' });
  assert.deepEqual(await profileIdentity(' '.repeat(262145)), { ok: false, error: 'too_large' });
  for (const value of ['1e3', '1000.0', '9007199254740993', 'NaN', 'Infinity', '-Infinity']) {
    assert.equal((await profileIdentity(fixture.replace('"min":1000', `"min":${value}`))).ok, false);
  }
});

test('catalog labels and mutable market fields cannot enter profile identity', async () => {
  for (const key of ['price', 'stock', 'observed_at', 'label', 'eligible']) {
    const text = fixture.replace('"schema":1', `"schema":1,"${key}":"value"`);
    assert.deepEqual(await profileIdentity(text), { ok: false, error: 'noncanonical' });
  }
});

test('unavailable cryptography refuses identity without a fallback', async (context) => {
  context.mock.method(globalThis.crypto.subtle, 'digest', async () => { throw new Error('unavailable'); });
  assert.deepEqual(await profileIdentity(fixture), { ok: false, error: 'crypto_unavailable' });
  assert.deepEqual(await profileIdentity('{}'), { ok: false, error: 'invalid_document' });
});
