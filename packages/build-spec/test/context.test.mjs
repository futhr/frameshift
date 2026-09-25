import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import {resolveContext} from '../js/context.mjs';

const read=name=>readFile(new URL(`./fixtures/context-v1/${name}.json`,import.meta.url),'utf8');
const assembly=await read('assembly');
const profiles=await Promise.all([0,1,2,3].map(n=>read('profile-'+n)));
const mappings=await Promise.all([0,1].map(n=>read('mapping-'+n)));
const canonical=await read('context');
const identity='sha256:6c3d7e88b4bdb95515f95d28448d3814e1b798c6d7203db3c825c28d17451e23';

test('verified context has the same canonical bytes and identity as BEAM',async()=>{
  const result=await resolveContext(assembly,profiles,mappings);
  assert.equal(result.ok,true);
  assert.equal(result.identity,identity);
  assert.equal(result.canonical,canonical);
  assert.equal(result.assembly_identity,JSON.parse(canonical).assembly);
  assert.deepEqual(result,await resolveContext(assembly,[...profiles].reverse(),[...mappings].reverse()));
  assert.equal(result.context.mappings.toArray().length,2);
  assert.deepEqual(result.context.resolution.missing.toArray(),[]);
  const changed=await resolveContext(assembly,profiles,[mappings[0].replace('test-1','test-2'),mappings[1]]);
  assert.equal(changed.ok,true);
  assert.notEqual(changed.identity,identity);
  assert.equal(changed.assembly_identity,result.assembly_identity);
});

test('stale scope, duplicate revisions, nonexistent ports and changed profiles refuse',async()=>{
  const changed=JSON.parse(mappings[0]);
  for(const document of [
    {...changed,firmware:'other'},
    {...changed,profile:'sha256:'+'9'.repeat(64)},
    {...changed,pairs:[{input:'absent',output:'out'}]},
  ]) assert.deepEqual(await resolveContext(assembly,profiles,[JSON.stringify(document)+'\n']),{ok:false,error:'invalid_reference'});
  assert.deepEqual(await resolveContext(assembly,profiles,[mappings[0],mappings[0]]),{ok:false,error:'duplicate_identifier'});
  assert.deepEqual(await resolveContext(assembly,profiles,[mappings[0],mappings[0].replace('test-1','test-2')]),{ok:false,error:'duplicate_identifier'});
  assert.deepEqual(await resolveContext(assembly,profiles,[mappings[0]+' ']),{ok:false,error:'noncanonical'});
  assert.deepEqual(await resolveContext(assembly,[profiles[0].replace('"part_revision":"R1"','"part_revision":"R2"'),...profiles.slice(1)],mappings),{ok:false,error:'unreferenced_profile'});
});

test('missing bodies stay explicit while supplied maps cannot resolve missing profiles',async()=>{
  const result=await resolveContext(assembly,[],[]);
  assert.equal(result.ok,true);
  assert.equal(result.context.resolution.missing.toArray().length,4);
  assert.equal(result.context.mappings.toArray().length,0);
  assert.notEqual(result.identity,identity);
  assert.deepEqual(await resolveContext(assembly,[],mappings),{ok:false,error:'invalid_reference'});
});

test('combined budgets and untrusted collection types fail before cryptography',async context=>{
  let hashes=0;
  context.mock.method(globalThis.crypto.subtle,'digest',async()=>{hashes++;throw new Error('unexpected');});
  for(const bad of [null,{},[undefined],new Array(1),[{identity:'fake',bytes:mappings[0]}]]) {
    assert.deepEqual(await resolveContext(assembly,profiles,bad),{ok:false,error:'invalid_document'});
    assert.deepEqual(await resolveContext(assembly,bad,mappings),{ok:false,error:'invalid_document'});
  }
  assert.deepEqual(await resolveContext(null,[],[]),{ok:false,error:'invalid_document'});
  assert.deepEqual(await resolveContext(assembly,[],Array(65).fill('')),{ok:false,error:'invalid_count'});
  assert.deepEqual(await resolveContext(assembly,Array(65).fill(''),[]),{ok:false,error:'invalid_count'});
  assert.deepEqual(await resolveContext(assembly,[],['x'.repeat(262145)]),{ok:false,error:'too_large'});
  assert.deepEqual(await resolveContext(assembly,[],['é'.repeat(131073)]),{ok:false,error:'too_large'});
  assert.deepEqual(await resolveContext(assembly,Array(8).fill('x'.repeat(262144)),Array(8).fill('x'.repeat(262144))),{ok:false,error:'too_large'});
  assert.equal(hashes,0);
});

test('async hashing uses a stable snapshot of both caller arrays',async context=>{
  const mutableProfiles=[...profiles];
  const mutableMappings=[...mappings];
  const digest=globalThis.crypto.subtle.digest.bind(globalThis.crypto.subtle);
  context.mock.method(globalThis.crypto.subtle,'digest',async(...args)=>{
    mutableProfiles.splice(0,mutableProfiles.length,'x'.repeat(262145));
    mutableMappings.splice(0,mutableMappings.length,'{}');
    return digest(...args);
  });
  const result=await resolveContext(assembly,mutableProfiles,mutableMappings);
  assert.equal(result.ok,true);
  assert.equal(result.identity,identity);
});

test('cryptography loss refuses even an unresolved context',async context=>{
  context.mock.method(globalThis.crypto.subtle,'digest',async()=>{throw new Error('offline');});
  assert.deepEqual(await resolveContext(assembly,[],[]),{ok:false,error:'crypto_unavailable'});
});
