import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import {mappingIdentity} from '../js/mapping.mjs';

const fixture = await readFile(new URL('./fixtures/mapping-v1.json', import.meta.url), 'utf8');
const identity = 'sha256:823315f13db255db83b81f9977962c90fec76d6cbd8dba66eb315b74049a8b2d';

test('mapping identity matches the BEAM fixture and changes with every scoped input', async () => {
  assert.deepEqual(await mappingIdentity(fixture), {ok:true,identity});
  for (const [from,to] of [['fixture-fw-0','fixture-fw-1'],['fixture-rgb24','other-format'],
    ['fixture-protocol','other-protocol'],['test-1','test-2'],['out-0','out-1'],
    ['sha256:'+'a'.repeat(64),'sha256:'+'b'.repeat(64)]]) {
    const changed = await mappingIdentity(fixture.replace(from,to));
    assert.equal(changed.ok,true);
    assert.notEqual(changed.identity,identity);
  }
});

test('mapping adapters refuse untrusted types and exceedance before hashing', async () => {
  for (const input of [null,undefined,1,{},new Uint8Array([255]),'{}','"\\uD800"']) {
    assert.deepEqual(await mappingIdentity(input),{ok:false,error:'invalid_document'});
  }
  assert.deepEqual(await mappingIdentity(' '.repeat(262145)),{ok:false,error:'too_large'});
  assert.deepEqual(await mappingIdentity('['.repeat(17)),{ok:false,error:'too_deep'});
  assert.deepEqual(await mappingIdentity(' '+fixture),{ok:false,error:'noncanonical'});
});

test('approval and mutable fields cannot enter mapping identity', async () => {
  for (const key of ['approved','revoked','label','price','expires_at']) {
    const changed = fixture.replace('"schema":1',`"schema":1,"${key}":true`);
    assert.deepEqual(await mappingIdentity(changed),{ok:false,error:'noncanonical'});
  }
});

test('missing browser cryptography never creates a substitute mapping identity', async (context) => {
  context.mock.method(globalThis.crypto.subtle,'digest',async () => {throw new Error('offline');});
  assert.deepEqual(await mappingIdentity(fixture),{ok:false,error:'crypto_unavailable'});
  assert.deepEqual(await mappingIdentity('{}'),{ok:false,error:'invalid_document'});
});
